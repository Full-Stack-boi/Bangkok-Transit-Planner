import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/station.dart';
import '../../models/route_result.dart';
import '../../models/searchable_item.dart';
import '../../models/custom_location.dart';
import '../../models/station_exit.dart';
import '../../models/landmark.dart';
import '../../repositories/transit_repository.dart';
import '../../services/dijkstra_planner.dart';
import '../../services/fare_service.dart';
import '../../services/walking_route_service.dart';
import '../../core/constants/transit_constants.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Card state snapshot passed to RouteCalculator to avoid Riverpod dependency.
class CardStateSnapshot {
  final String btsCardType;
  final String mrtCardType;
  final String arlCardType;
  final String srtCardType;

  const CardStateSnapshot({
    this.btsCardType = 'standard',
    this.mrtCardType = 'standard',
    this.arlCardType = 'standard',
    this.srtCardType = 'standard',
  });
}

/// Translation strings needed by RouteCalculator.
class RouteTranslations {
  final String walkToStation;
  final String walkToDestination;
  final String errorSamePlaces;
  final String errorNoRoute;
  final String Function(String) errorFailed;

  const RouteTranslations({
    required this.walkToStation,
    required this.walkToDestination,
    required this.errorSamePlaces,
    required this.errorNoRoute,
    required this.errorFailed,
  });
}

/// Result of a route calculation — contains recommended and optional saver route.
class CalculationResult {
  final RouteResult recommended;
  final RouteResult? saver;
  final String? error;

  const CalculationResult({
    required this.recommended,
    this.saver,
    this.error,
  });
}

/// Encapsulates all route calculation logic extracted from SearchViewModel:
/// - Dijkstra path finding
/// - Fare calculation
/// - Walk segment building
/// - Saver route search
/// - Walking path hydration
class RouteCalculator {
  final TransitRepository _repo;
  final FareService _fareService;
  final http.Client _httpClient;

  RouteCalculator(this._repo, this._fareService, this._httpClient);

  // ──────────────────────────────────────────────────────────────
  //  Public API
  // ──────────────────────────────────────────────────────────────

  /// Calculate routes between origin and destination.
  /// Returns [CalculationResult] with recommended + optional saver route,
  /// or a result with [error] if calculation fails.
  CalculationResult? calculate(
    SearchableItem origin,
    SearchableItem destination,
    CardStateSnapshot cardState,
    RouteTranslations t,
  ) {
    if (origin.id == destination.id) {
      return null; // Same place error — handled by caller
    }

    var resolvedOrigin = origin;
    var resolvedDestination = destination;

    // Dynamic entrance & station resolution for CustomLocation
    if (destination is CustomLocation) {
      final originStationId = origin.nearestStationId ?? origin.id;
      resolvedDestination = _resolveLocationEntrance(
        resolvedDestination as CustomLocation,
        originStationId,
        false,
      );
    }
    if (origin is CustomLocation) {
      final destStationId = resolvedDestination.nearestStationId ?? resolvedDestination.id;
      resolvedOrigin = _resolveLocationEntrance(
        resolvedOrigin as CustomLocation,
        destStationId,
        true,
      );
    }

    final originStationId = resolvedOrigin.nearestStationId ?? resolvedOrigin.id;
    final destinationStationId = resolvedDestination.nearestStationId ?? resolvedDestination.id;

    // Exit-to-entrance optimization when both resolve to the same station
    if (originStationId == destinationStationId) {
      final optimized = _optimizeSameStationEntrances(
        resolvedOrigin, resolvedDestination,
      );
      resolvedOrigin = optimized.$1;
      resolvedDestination = optimized.$2;
    }

    RouteResult routeResult;

    if (originStationId == destinationStationId) {
      // Direct walk scenario
      routeResult = _buildDirectWalkRoute(
        resolvedOrigin, resolvedDestination,
        originStationId, destinationStationId, t,
      );
    } else {
      final dijkstra = _repo.findRoute(originStationId, destinationStationId);
      if (dijkstra == null) {
        return null; // No route error — handled by caller
      }
      routeResult = buildRouteResult(
        dijkstra, resolvedOrigin, resolvedDestination, cardState, t,
      );
    }

    // Calculate saver route
    final saverRoute = _findSaverRoute(
      resolvedOrigin, resolvedDestination,
      routeResult, cardState, t,
    );

    return CalculationResult(
      recommended: routeResult,
      saver: saverRoute,
    );
  }

  /// Hydrate walking paths for recommended and saver routes via OSRM.
  Future<(RouteResult, RouteResult?)> hydrateRoutes(
    RouteResult recommended,
    RouteResult? saver,
  ) async {
    final hydratedRecommended = await _hydrateRouteWalkingPaths(recommended);
    RouteResult? hydratedSaver;
    if (saver != null) {
      hydratedSaver = await _hydrateRouteWalkingPaths(saver);
    }
    return (hydratedRecommended, hydratedSaver);
  }

  // ──────────────────────────────────────────────────────────────
  //  Entrance Resolution
  // ──────────────────────────────────────────────────────────────

  List<Station> _getCandidateStations(CustomLocation loc) {
    final list = <Station>[];
    for (final station in _repo.stations) {
      final dist = Geolocator.distanceBetween(
        loc.routeLat, loc.routeLng, station.lat, station.lng,
      );
      if (dist <= 700.0) {
        list.add(station);
      }
    }
    final nearest = _repo.findNearestStation(loc.routeLat, loc.routeLng);
    if (nearest != null && !list.any((s) => s.id == nearest.id)) {
      list.add(nearest);
    }
    return list;
  }

  CustomLocation _resolveLocationEntrance(
    CustomLocation loc,
    String targetStationId,
    bool isOrigin,
  ) {
    final candidates = _getCandidateStations(loc);
    double minTime = double.infinity;
    String bestStationId = loc.nearestStationId ?? loc.id;
    LatLng bestRoutePoint = LatLng(loc.lat, loc.lng);

    for (final station in candidates) {
      LatLng targetEntrance = LatLng(loc.lat, loc.lng);
      double minDist = Geolocator.distanceBetween(
        targetEntrance.latitude, targetEntrance.longitude,
        station.lat, station.lng,
      );

      if (loc.entrances != null && loc.entrances!.isNotEmpty) {
        for (final ent in loc.entrances!) {
          final d = Geolocator.distanceBetween(
            ent.latitude, ent.longitude, station.lat, station.lng,
          );
          if (d < minDist) {
            minDist = d;
            targetEntrance = ent;
          }
        }
      }

      final walkMinutes = minDist / 80.0;
      double totalTime = walkMinutes;

      if (targetStationId != station.id) {
        final route = isOrigin
            ? _repo.findRoute(station.id, targetStationId)
            : _repo.findRoute(targetStationId, station.id);
        if (route != null) {
          totalTime += route.totalWeight;
        } else {
          continue;
        }
      }

      if (totalTime < minTime) {
        minTime = totalTime;
        bestStationId = station.id;
        bestRoutePoint = targetEntrance;
      }
    }

    final bestStation = _repo.getStation(bestStationId);
    final newWalkDist = bestStation != null
        ? Geolocator.distanceBetween(
            bestRoutePoint.latitude, bestRoutePoint.longitude,
            bestStation.lat, bestStation.lng,
          )
        : 0.0;
    final newWalkMinutes = (newWalkDist / 80.0).clamp(1.0, 30.0);

    return loc.updateRoute(
      routeLat: bestRoutePoint.latitude,
      routeLng: bestRoutePoint.longitude,
      nearestStationId: bestStationId,
      walkingMinutes: newWalkMinutes,
      clearWalkingPath: true,
    );
  }

  (SearchableItem, SearchableItem) _optimizeSameStationEntrances(
    SearchableItem origin,
    SearchableItem destination,
  ) {
    var resolvedOrigin = origin;
    var resolvedDestination = destination;

    if (resolvedDestination is CustomLocation &&
        resolvedDestination.entrances != null &&
        resolvedDestination.entrances!.isNotEmpty) {
      double minDist = double.infinity;
      LatLng? bestEntrance;
      for (final entrance in resolvedDestination.entrances!) {
        final dist = Geolocator.distanceBetween(
          entrance.latitude, entrance.longitude,
          resolvedOrigin.routeLat, resolvedOrigin.routeLng,
        );
        if (dist < minDist) {
          minDist = dist;
          bestEntrance = entrance;
        }
      }
      if (bestEntrance != null) {
        resolvedDestination = resolvedDestination.copyWith(
          customRouteLat: bestEntrance.latitude,
          customRouteLng: bestEntrance.longitude,
        );
      }
    }
    if (resolvedOrigin is CustomLocation &&
        resolvedOrigin.entrances != null &&
        resolvedOrigin.entrances!.isNotEmpty) {
      double minDist = double.infinity;
      LatLng? bestEntrance;
      for (final entrance in resolvedOrigin.entrances!) {
        final dist = Geolocator.distanceBetween(
          entrance.latitude, entrance.longitude,
          resolvedDestination.routeLat, resolvedDestination.routeLng,
        );
        if (dist < minDist) {
          minDist = dist;
          bestEntrance = entrance;
        }
      }
      if (bestEntrance != null) {
        resolvedOrigin = resolvedOrigin.copyWith(
          customRouteLat: bestEntrance.latitude,
          customRouteLng: bestEntrance.longitude,
        );
      }
    }

    return (resolvedOrigin, resolvedDestination);
  }

  // ──────────────────────────────────────────────────────────────
  //  Direct Walk Route (same station)
  // ──────────────────────────────────────────────────────────────

  RouteResult _buildDirectWalkRoute(
    SearchableItem origin,
    SearchableItem destination,
    String originStationId,
    String destinationStationId,
    RouteTranslations t,
  ) {
    StationExit? exit;
    List<LatLng>? walkingPath;
    double walkMinutes =
        (origin.walkingMinutes ?? 0.0) + (destination.walkingMinutes ?? 0.0);

    Landmark? lm;
    Station? st;
    if (origin is Landmark) {
      lm = origin;
      st = _repo.getStation(destinationStationId);
    } else if (destination is Landmark) {
      lm = destination;
      st = _repo.getStation(originStationId);
    }

    if (lm == null) {
      for (final l in _repo.landmarks) {
        if (l.id == origin.id) {
          lm = l;
          st = _repo.getStation(destinationStationId);
          break;
        } else if (l.id == destination.id) {
          lm = l;
          st = _repo.getStation(originStationId);
          break;
        }
      }
    }

    if (lm != null && st != null) {
      _resolveWalkDetails(lm, st, (resolvedExit, resolvedPath, resolvedMinutes) {
        exit = resolvedExit;
        walkingPath = resolvedPath;
        if (resolvedMinutes != null) walkMinutes = resolvedMinutes;
      });
    }

    exit ??= st?.findClosestExit(
      _repo.exits,
      destination.routeLat, destination.routeLng,
      targetNameTh: destination.nameTh,
      targetNameEn: destination.nameEn,
    );
    walkingPath ??= [
      LatLng(origin.routeLat, origin.routeLng),
      LatLng(destination.routeLat, destination.routeLng),
    ];

    String direction = t.walkToDestination;
    String? instructionsTh;
    String? instructionsEn;
    if (lm != null && st != null &&
        lm.alternativeWalks != null &&
        lm.alternativeWalks!.containsKey(st.id)) {
      final sw = lm.alternativeWalks![st.id]!;
      instructionsTh = sw.instructionsTh;
      instructionsEn = sw.instructionsEn;
      if (instructionsTh != null) direction = instructionsTh;
    }

    final walkSegment = RouteSegment(
      lineId: 'WALK',
      lineName: 'Walk',
      direction: direction,
      boundIndex: 0,
      fromStation: origin,
      toStation: destination,
      stationCount: 0,
      estimatedMinutes: walkMinutes > 0 ? walkMinutes : 5.0,
      fareThb: 0,
      standardFareThb: 0,
      walkingPath: walkingPath,
      exit: exit,
      instructionsTh: instructionsTh,
      instructionsEn: instructionsEn,
    );

    return RouteResult(
      origin: origin,
      destination: destination,
      segments: [walkSegment],
      transfers: [],
      totalMinutes: walkMinutes > 0 ? walkMinutes : 5.0,
      totalFareThb: 0,
      totalStandardFareThb: 0,
      totalStations: 0,
      calculatedAt: DateTime.now(),
    );
  }

  /// Resolve walk details (exit, path, minutes) for a landmark-station pair.
  void _resolveWalkDetails(
    Landmark lm,
    Station st,
    void Function(StationExit?, List<LatLng>?, double?) callback,
  ) {
    if (st.id == lm.nearestStationId && lm.walkingPath != null) {
      List<LatLng>? path = lm.walkingPath;
      double? minutes;
      StationExit? exit;
      if (lm.exitCode != null) {
        final exits = _repo.getExitsForStation(st.id);
        exit = exits.firstWhere(
          (e) => e.exitCode == lm.exitCode,
          orElse: () => st.findClosestExit(
            _repo.exits, lm.routeLat, lm.routeLng,
            targetNameTh: lm.nameTh, targetNameEn: lm.nameEn,
          ),
        );
      }
      callback(exit, path, minutes);
    } else if (lm.alternativeWalks != null &&
        lm.alternativeWalks!.containsKey(st.id)) {
      final walk = lm.alternativeWalks![st.id]!;
      final exits = _repo.getExitsForStation(st.id);
      final exit = exits.firstWhere(
        (e) => e.exitCode == walk.exitCode,
        orElse: () => st.findClosestExit(
          _repo.exits, lm.routeLat, lm.routeLng,
          targetNameTh: lm.nameTh, targetNameEn: lm.nameEn,
        ),
      );
      callback(exit, walk.walkingPath, walk.walkingMinutes);
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Build RouteResult from Dijkstra
  // ──────────────────────────────────────────────────────────────

  RouteResult buildRouteResult(
    DijkstraResult dijkstraResult,
    SearchableItem origin,
    SearchableItem destination,
    CardStateSnapshot cardState,
    RouteTranslations t,
  ) {
    final segments = <RouteSegment>[];
    final transfers = <TransferStep>[];

    // ─── 1. If Origin requires walking, add initial Walk Segment ───
    _addOriginWalkSegment(segments, origin, t);

    // ─── 2. Group path steps by line ───
    _buildTransitSegments(dijkstraResult, segments, transfers, cardState);

    // ─── 3. If Destination requires walking, add final Walk Segment ───
    _addDestinationWalkSegment(segments, destination, t);

    final totalFare = segments.fold<int>(0, (sum, s) => sum + s.fareThb);
    final totalStandardFare = segments.fold<int>(0, (sum, s) => sum + s.standardFareThb);

    double totalMinutes = dijkstraResult.totalWeight;
    if (origin.walkingMinutes != null) totalMinutes += origin.walkingMinutes!;
    if (destination.walkingMinutes != null) totalMinutes += destination.walkingMinutes!;

    return RouteResult(
      origin: origin,
      destination: destination,
      segments: segments,
      transfers: transfers,
      totalMinutes: totalMinutes,
      totalFareThb: totalFare,
      totalStandardFareThb: totalStandardFare,
      totalStations: dijkstraResult.path.length - 1,
      calculatedAt: DateTime.now(),
    );
  }

  void _addOriginWalkSegment(
    List<RouteSegment> segments,
    SearchableItem origin,
    RouteTranslations t,
  ) {
    if (origin.nearestStationId == null || origin.id == origin.nearestStationId) return;

    final nearestStation = _repo.getStation(origin.nearestStationId!);
    if (nearestStation == null) return;

    StationExit? exit;
    List<LatLng>? walkingPath;
    double walkingMinutes = origin.walkingMinutes ?? 5.0;

    Landmark? originLandmark;
    if (origin is Landmark) {
      originLandmark = origin;
    } else {
      for (final l in _repo.landmarks) {
        if (l.id == origin.id) { originLandmark = l; break; }
      }
    }

    if (originLandmark != null) {
      _resolveWalkDetails(originLandmark, nearestStation, (e, p, m) {
        exit = e;
        walkingPath = p;
        if (m != null) walkingMinutes = m;
      });
    }

    if (origin is CustomLocation && origin.walkingPath != null) {
      walkingPath = origin.walkingPath;
    }

    exit ??= nearestStation.findClosestExit(
      _repo.exits, origin.routeLat, origin.routeLng,
      targetNameTh: origin.nameTh, targetNameEn: origin.nameEn,
    );
    walkingPath ??= [
      LatLng(origin.routeLat, origin.routeLng),
      LatLng(exit!.lat, exit!.lng),
    ];

    String direction = t.walkToStation;
    String? instructionsTh;
    String? instructionsEn;
    if (originLandmark != null &&
        originLandmark.alternativeWalks != null &&
        originLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
      final walk = originLandmark.alternativeWalks![nearestStation.id]!;
      instructionsTh = walk.instructionsTh;
      instructionsEn = walk.instructionsEn;
      if (instructionsTh != null) direction = instructionsTh;
    }

    segments.add(RouteSegment(
      lineId: 'WALK', lineName: 'Walk', direction: direction,
      boundIndex: 0, fromStation: origin, toStation: nearestStation,
      stationCount: 0, estimatedMinutes: walkingMinutes,
      fareThb: 0, standardFareThb: 0,
      walkingPath: walkingPath, exit: exit,
      instructionsTh: instructionsTh, instructionsEn: instructionsEn,
    ));
  }

  void _addDestinationWalkSegment(
    List<RouteSegment> segments,
    SearchableItem destination,
    RouteTranslations t,
  ) {
    if (destination.nearestStationId == null || destination.id == destination.nearestStationId) return;

    final nearestStation = _repo.getStation(destination.nearestStationId!);
    if (nearestStation == null) return;

    StationExit? exit;
    List<LatLng>? walkingPath;
    double walkingMinutes = destination.walkingMinutes ?? 5.0;

    Landmark? destLandmark;
    if (destination is Landmark) {
      destLandmark = destination;
    } else {
      for (final l in _repo.landmarks) {
        if (l.id == destination.id) { destLandmark = l; break; }
      }
    }

    if (destLandmark != null) {
      _resolveWalkDetails(destLandmark, nearestStation, (e, p, m) {
        exit = e;
        walkingPath = p;
        if (m != null) walkingMinutes = m;
      });
    }

    if (destination is CustomLocation && destination.walkingPath != null) {
      walkingPath = destination.walkingPath;
    }

    exit ??= nearestStation.findClosestExit(
      _repo.exits, destination.routeLat, destination.routeLng,
      targetNameTh: destination.nameTh, targetNameEn: destination.nameEn,
    );
    walkingPath ??= [
      LatLng(exit!.lat, exit!.lng),
      LatLng(destination.routeLat, destination.routeLng),
    ];

    String direction = t.walkToDestination;
    String? instructionsTh;
    String? instructionsEn;
    if (destLandmark != null &&
        destLandmark.alternativeWalks != null &&
        destLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
      final walk = destLandmark.alternativeWalks![nearestStation.id]!;
      instructionsTh = walk.instructionsTh;
      instructionsEn = walk.instructionsEn;
      if (instructionsTh != null) direction = instructionsTh;
    }

    segments.add(RouteSegment(
      lineId: 'WALK', lineName: 'Walk', direction: direction,
      boundIndex: 0, fromStation: nearestStation, toStation: destination,
      stationCount: 0, estimatedMinutes: walkingMinutes,
      fareThb: 0, standardFareThb: 0,
      walkingPath: walkingPath, exit: exit,
      instructionsTh: instructionsTh, instructionsEn: instructionsEn,
    ));
  }

  void _buildTransitSegments(
    DijkstraResult dijkstraResult,
    List<RouteSegment> segments,
    List<TransferStep> transfers,
    CardStateSnapshot cardState,
  ) {
    String currentLineId = '';
    Station? segmentStart;
    final segmentStations = <Station>[];

    for (int i = 0; i < dijkstraResult.path.length; i++) {
      final step = dijkstraResult.path[i];
      final station = _repo.getStation(step.stationId);
      if (station == null) continue;

      if (step.lineId == 'TRANSFER') {
        _flushSegment(segments, currentLineId, segmentStart, segmentStations, cardState);

        if (segmentStations.isNotEmpty) {
          final nextLineId = i + 1 < dijkstraResult.path.length
              ? dijkstraResult.path[i + 1].lineId
              : '';
          transfers.add(TransferStep(
            fromStation: segmentStations.last,
            toStation: station,
            fromLineId: currentLineId,
            toLineId: nextLineId,
          ));
        }

        segmentStart = station;
        segmentStations.clear();
        segmentStations.add(station);
        currentLineId = i + 1 < dijkstraResult.path.length
            ? dijkstraResult.path[i + 1].lineId
            : '';
        continue;
      }

      if (step.lineId.isNotEmpty && step.lineId != currentLineId) {
        if (currentLineId.isEmpty) {
          currentLineId = step.lineId;
        } else {
          _flushSegment(segments, currentLineId, segmentStart, segmentStations, cardState);
          currentLineId = step.lineId;
          segmentStart = station;
          segmentStations.clear();
        }
      }

      if (segmentStart == null) {
        segmentStart = station;
        currentLineId = step.lineId.isNotEmpty ? step.lineId : currentLineId;
      }
      segmentStations.add(station);
    }

    // Flush last segment
    _flushSegment(segments, currentLineId, segmentStart, segmentStations, cardState);
  }

  void _flushSegment(
    List<RouteSegment> segments,
    String lineId,
    Station? segmentStart,
    List<Station> segmentStations,
    CardStateSnapshot cardState,
  ) {
    if (segmentStart == null || segmentStations.length <= 1) return;

    final line = _repo.getLine(lineId);
    final stationCount = segmentStations.length - 1;
    final bound = line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

    final standardFare = _fareService.calculateFare(lineId, stationCount);
    final discountedFare = _fareService.calculateFare(
      lineId, stationCount,
      btsCardType: cardState.btsCardType,
      mrtCardType: cardState.mrtCardType,
      arlCardType: cardState.arlCardType,
      srtCardType: cardState.srtCardType,
    );

    segments.add(RouteSegment(
      lineId: lineId,
      lineName: line?.nameEn ?? lineId,
      direction: line?.getDirectionLabel(bound) ?? '',
      boundIndex: bound,
      fromStation: segmentStart,
      toStation: segmentStations.last,
      intermediateStations: segmentStations.length > 2
          ? segmentStations.sublist(1, segmentStations.length - 1)
          : [],
      stationCount: stationCount,
      estimatedMinutes: stationCount * TransitConstants.avgTimeBetweenStations,
      fareThb: discountedFare,
      standardFareThb: standardFare,
    ));
  }

  // ──────────────────────────────────────────────────────────────
  //  Saver Route
  // ──────────────────────────────────────────────────────────────

  RouteResult? _findSaverRoute(
    SearchableItem origin,
    SearchableItem destination,
    RouteResult regularRoute,
    CardStateSnapshot cardState,
    RouteTranslations t,
  ) {
    if (regularRoute.segments.isEmpty ||
        regularRoute.segments.every((s) => s.lineId == 'WALK')) {
      return null;
    }

    final originStationId = origin.nearestStationId ?? origin.id;
    final destinationStationId = destination.nearestStationId ?? destination.id;

    final destLat = destination.routeLat;
    final destLng = destination.routeLng;
    final originLat = origin.routeLat;
    final originLng = origin.routeLng;

    final candidateDestStations = _findCandidateStations(
      destLat, destLng, destinationStationId,
      destination is CustomLocation ? destination.entrances : null,
    );
    final candidateOriginStations = _findCandidateStations(
      originLat, originLng, originStationId,
      origin is CustomLocation ? origin.entrances : null,
    );

    RouteResult? bestSaverRoute;

    void evaluateCandidate({
      required String startId, required String endId,
      required double startWalkMin, required double endWalkMin,
      required double altOriginRouteLat, required double altOriginRouteLng,
      required double altDestRouteLat, required double altDestRouteLng,
    }) {
      final dijkstraResult = _repo.findRoute(startId, endId);
      if (dijkstraResult == null) return;

      final tempOrigin = CustomLocation(
        id: origin.id, nameTh: origin.nameTh, nameEn: origin.nameEn,
        nearestStationId: startId, walkingMinutes: startWalkMin,
        lat: originLat, lng: originLng,
        customRouteLat: altOriginRouteLat, customRouteLng: altOriginRouteLng,
        entrances: origin is CustomLocation ? origin.entrances : null,
        walkingPath: origin is CustomLocation ? origin.walkingPath : null,
      );
      final tempDest = CustomLocation(
        id: destination.id, nameTh: destination.nameTh, nameEn: destination.nameEn,
        nearestStationId: endId, walkingMinutes: endWalkMin,
        lat: destLat, lng: destLng,
        customRouteLat: altDestRouteLat, customRouteLng: altDestRouteLng,
        entrances: destination is CustomLocation ? destination.entrances : null,
        walkingPath: destination is CustomLocation ? destination.walkingPath : null,
      );

      final altRoute = buildRouteResult(dijkstraResult, tempOrigin, tempDest, cardState, t);

      final isCheaper = altRoute.totalFareThb < regularRoute.totalFareThb;
      final isNotTooSlow = altRoute.totalMinutes <= regularRoute.totalMinutes + 15.0;

      if (isCheaper && isNotTooSlow) {
        final currentBest = bestSaverRoute;
        if (currentBest == null ||
            altRoute.totalFareThb < currentBest.totalFareThb ||
            (altRoute.totalFareThb == currentBest.totalFareThb &&
                altRoute.transferCount < currentBest.transferCount)) {
          bestSaverRoute = altRoute;
        }
      }
    }

    for (final altDest in candidateDestStations) {
      evaluateCandidate(
        startId: originStationId, endId: altDest.station.id,
        startWalkMin: origin.walkingMinutes ?? 0.0, endWalkMin: altDest.walkMinutes,
        altOriginRouteLat: originLat, altOriginRouteLng: originLng,
        altDestRouteLat: altDest.entrance.latitude, altDestRouteLng: altDest.entrance.longitude,
      );
    }
    for (final altOrigin in candidateOriginStations) {
      evaluateCandidate(
        startId: altOrigin.station.id, endId: destinationStationId,
        startWalkMin: altOrigin.walkMinutes, endWalkMin: destination.walkingMinutes ?? 0.0,
        altOriginRouteLat: altOrigin.entrance.latitude, altOriginRouteLng: altOrigin.entrance.longitude,
        altDestRouteLat: destLat, altDestRouteLng: destLng,
      );
    }
    for (final altOrigin in candidateOriginStations) {
      for (final altDest in candidateDestStations) {
        evaluateCandidate(
          startId: altOrigin.station.id, endId: altDest.station.id,
          startWalkMin: altOrigin.walkMinutes, endWalkMin: altDest.walkMinutes,
          altOriginRouteLat: altOrigin.entrance.latitude, altOriginRouteLng: altOrigin.entrance.longitude,
          altDestRouteLat: altDest.entrance.latitude, altDestRouteLng: altDest.entrance.longitude,
        );
      }
    }

    return bestSaverRoute;
  }

  List<({Station station, LatLng entrance, double walkMinutes})> _findCandidateStations(
    double lat, double lng, String excludeId, List<LatLng>? entrances,
  ) {
    final result = <({Station station, LatLng entrance, double walkMinutes})>[];
    for (final station in _repo.stations) {
      if (station.id == excludeId) continue;

      LatLng targetEntrance = LatLng(lat, lng);
      double minDist = Geolocator.distanceBetween(lat, lng, station.lat, station.lng);

      if (entrances != null && entrances.isNotEmpty) {
        double dMin = double.infinity;
        for (final ent in entrances) {
          final d = Geolocator.distanceBetween(
            ent.latitude, ent.longitude, station.lat, station.lng,
          );
          if (d < dMin) { dMin = d; targetEntrance = ent; }
        }
        minDist = dMin;
      }

      if (minDist <= 700.0) {
        result.add((
          station: station,
          entrance: targetEntrance,
          walkMinutes: (minDist / 80.0).clamp(1.0, 30.0),
        ));
      }
    }
    return result;
  }

  // ──────────────────────────────────────────────────────────────
  //  Walking Path Hydration
  // ──────────────────────────────────────────────────────────────

  Future<RouteResult> _hydrateRouteWalkingPaths(RouteResult route) async {
    final hydratedSegments = <RouteSegment>[];
    bool modified = false;

    for (final segment in route.segments) {
      if (segment.lineId == 'WALK') {
        final from = segment.fromStation;
        final to = segment.toStation;

        // Skip precalculated landmark paths
        if (_isPrecalculatedPath(from, to)) {
          hydratedSegments.add(segment);
          continue;
        }

        double fLat, fLng, tLat, tLng;
        if (segment.exit != null) {
          if (from is Station) {
            fLat = segment.exit!.lat; fLng = segment.exit!.lng;
            tLat = to.routeLat; tLng = to.routeLng;
          } else {
            fLat = from.routeLat; fLng = from.routeLng;
            tLat = segment.exit!.lat; tLng = segment.exit!.lng;
          }
        } else {
          fLat = from.routeLat; fLng = from.routeLng;
          tLat = to.routeLat; tLng = to.routeLng;
        }

        final walkingService = WalkingRouteService(_httpClient);
        List<LatLng> path = await walkingService.getWalkingPath(fLat, fLng, tLat, tLng);

        final straightDist = Geolocator.distanceBetween(fLat, fLng, tLat, tLng);
        if (straightDist < 150.0) {
          path = [LatLng(fLat, fLng), LatLng(tLat, tLng)];
        } else if (straightDist < 600.0 && path.isNotEmpty) {
          double pathDist = 0.0;
          for (int idx = 0; idx < path.length - 1; idx++) {
            pathDist += Geolocator.distanceBetween(
              path[idx].latitude, path[idx].longitude,
              path[idx + 1].latitude, path[idx + 1].longitude,
            );
          }
          if (pathDist > 4.0 * straightDist) {
            AppLogger.info("OSRM extreme detour detected (OSRM: ${pathDist.toStringAsFixed(1)}m, Straight: ${straightDist.toStringAsFixed(1)}m). Falling back to direct straight-line path.");
            path = [LatLng(fLat, fLng), LatLng(tLat, tLng)];
          } else if (pathDist > 2.8 * straightDist) {
            AppLogger.info("OSRM significant detour detected (OSRM: ${pathDist.toStringAsFixed(1)}m, Straight: ${straightDist.toStringAsFixed(1)}m). Falling back to smart L-shape path.");
            path = WalkingRouteService.generateManhattanPath(fLat, fLng, tLat, tLng);
          }
        }

        hydratedSegments.add(RouteSegment(
          lineId: segment.lineId, lineName: segment.lineName,
          direction: segment.direction, boundIndex: segment.boundIndex,
          fromStation: segment.fromStation, toStation: segment.toStation,
          intermediateStations: segment.intermediateStations,
          stationCount: segment.stationCount,
          estimatedMinutes: segment.estimatedMinutes,
          fareThb: segment.fareThb, standardFareThb: segment.standardFareThb,
          walkingPath: path, exit: segment.exit,
          instructionsTh: segment.instructionsTh,
          instructionsEn: segment.instructionsEn,
        ));
        modified = true;
      } else {
        hydratedSegments.add(segment);
      }
    }

    if (modified) {
      return RouteResult(
        origin: route.origin, destination: route.destination,
        segments: hydratedSegments, transfers: route.transfers,
        totalMinutes: route.totalMinutes, totalFareThb: route.totalFareThb,
        totalStandardFareThb: route.totalStandardFareThb,
        totalStations: route.totalStations, calculatedAt: route.calculatedAt,
      );
    }
    return route;
  }

  bool _isPrecalculatedPath(SearchableItem from, SearchableItem to) {
    Landmark? lm;
    Station? st;
    if (from is Landmark) { lm = from; if (to is Station) st = to; }
    else if (to is Landmark) { lm = to; if (from is Station) st = from; }

    if (lm == null) {
      for (final l in _repo.landmarks) {
        if (l.id == from.id) { lm = l; if (to is Station) st = to; break; }
        else if (l.id == to.id) { lm = l; if (from is Station) st = from; break; }
      }
    }

    if (lm != null && st != null) {
      if (st.id == lm.nearestStationId && lm.walkingPath != null) return true;
      if (lm.alternativeWalks != null && lm.alternativeWalks!.containsKey(st.id)) return true;
    }
    return false;
  }
}
