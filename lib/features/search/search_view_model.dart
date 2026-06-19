import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/station.dart';
import '../../models/route_result.dart';
import '../../models/searchable_item.dart';
import '../../models/custom_location.dart';
import '../../models/station_exit.dart';
import '../../models/landmark.dart';
import '../../providers/providers.dart';
import '../../services/dijkstra_planner.dart';
import '../../services/fare_service.dart';
import '../../services/walking_route_service.dart';
import '../../core/constants/transit_constants.dart';

part 'search_view_model.g.dart';

/// State for search feature
class SearchState {
  final String query;
  final List<SearchableItem> searchResults;
  final SearchableItem? origin;
  final SearchableItem? destination;
  final RouteResult? routeResult;
  final RouteResult? regularRoute;
  final RouteResult? saverRoute;
  final String activeRouteType; // 'recommended' or 'saver'
  final bool isCalculating;
  final String? error;

  const SearchState({
    this.query = '',
    this.searchResults = const [],
    this.origin,
    this.destination,
    this.routeResult,
    this.regularRoute,
    this.saverRoute,
    this.activeRouteType = 'recommended',
    this.isCalculating = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchableItem>? searchResults,
    SearchableItem? origin,
    SearchableItem? destination,
    RouteResult? routeResult,
    RouteResult? regularRoute,
    RouteResult? saverRoute,
    String? activeRouteType,
    bool? isCalculating,
    String? error,
    bool clearOrigin = false,
    bool clearDestination = false,
    bool clearRoute = false,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      searchResults: searchResults ?? this.searchResults,
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      routeResult: clearRoute ? null : (routeResult ?? this.routeResult),
      regularRoute: clearRoute ? null : (regularRoute ?? this.regularRoute),
      saverRoute: clearRoute ? null : (saverRoute ?? this.saverRoute),
      activeRouteType: activeRouteType ?? this.activeRouteType,
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ViewModel for search feature
@riverpod
class SearchViewModel extends _$SearchViewModel {
  bool _mounted = true;

  @override
  SearchState build() {
    _mounted = true;
    ref.onDispose(() {
      _mounted = false;
    });
    ref.listen(userCardsProvider, (previous, next) {
      if (state.origin != null && state.destination != null) {
        _tryCalculateRoute();
      }
    });
    return const SearchState();
  }

  /// Search stations and landmarks by query, querying online places if needed
  Future<void> search(String query) async {
    state = state.copyWith(query: query, clearError: true);

    final repo = ref.read(transitRepositoryProvider);

    // 1. Search local places (stations + landmarks) instantly
    final localResults = repo.searchLocalPlaces(query);
    state = state.copyWith(searchResults: localResults);

    if (query.trim().length >= 3) {
      // 2. Fetch online places in background
      try {
        final onlineResults = await repo.searchOnlinePlaces(query);

        // Merge without duplicates
        if (state.query == query) {
          final merged = [...localResults];
          for (final online in onlineResults) {
            if (!merged.any((item) =>
                item.nameTh.toLowerCase() == online.nameTh.toLowerCase() ||
                (item.lat == online.lat && item.lng == online.lng))) {
              merged.add(online);
            }
          }
          state = state.copyWith(searchResults: merged);
        }
      } catch (e) {
        print('Online place search failed: $e');
      }
    }
  }

  /// Set origin station or place
  void setOrigin(SearchableItem station) {
    state = state.copyWith(
      origin: station,
      clearRoute: true,
      clearError: true,
    );
    _tryCalculateRoute();
  }

  /// Set destination station or place
  void setDestination(SearchableItem station) {
    state = state.copyWith(
      destination: station,
      clearRoute: true,
      clearError: true,
    );
    _tryCalculateRoute();
  }

  /// Swap origin and destination
  void swapStations() {
    final origin = state.origin;
    final destination = state.destination;
    state = state.copyWith(
      origin: destination,
      destination: origin,
      clearRoute: true,
    );
    _tryCalculateRoute();
  }

  /// Clear all selections
  void clear() {
    state = const SearchState();
  }

  /// Calculate route if both origin and destination are set
  void _tryCalculateRoute() {
    final origin = state.origin;
    final destination = state.destination;
    final t = ref.read(translationsProvider);

    if (origin == null || destination == null) return;
    if (origin.id == destination.id) {
      state = state.copyWith(error: t.errors.errorSamePlaces);
      return;
    }

    state = state.copyWith(isCalculating: true, clearError: true);

    try {
      final repo = ref.read(transitRepositoryProvider);
      final fareService = ref.read(fareServiceProvider);

      final originStationId = origin.nearestStationId ?? origin.id;
      final destinationStationId = destination.nearestStationId ?? destination.id;

      RouteResult routeResult;

      if (originStationId == destinationStationId) {
        // Direct walk scenario (e.g. between landmarks near same station, or landmark and its station)
        StationExit? exit;
        List<LatLng>? walkingPath;
        double walkMinutes = (origin.walkingMinutes ?? 0.0) + (destination.walkingMinutes ?? 0.0);

        Landmark? lm;
        Station? st;
        if (origin is Landmark) {
          lm = origin;
          st = repo.getStation(destinationStationId);
        } else if (destination is Landmark) {
          lm = destination;
          st = repo.getStation(originStationId);
        }

        if (lm == null) {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == origin.id && l is Landmark) {
              lm = l;
              st = repo.getStation(destinationStationId);
              break;
            } else if (l.id == destination.id && l is Landmark) {
              lm = l;
              st = repo.getStation(originStationId);
              break;
            }
          }
        }

        if (lm != null && st != null) {
          final landmark = lm;
          final station = st;
          if (station.id == landmark.nearestStationId && landmark.walkingPath != null) {
            walkingPath = landmark.walkingPath;
            walkMinutes = landmark.walkingMinutes;
            if (landmark.exitCode != null) {
              final exits = repo.getExitsForStation(station.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == landmark.exitCode,
                orElse: () => station.findClosestExit(repo.exits, landmark.routeLat, landmark.routeLng),
              );
            }
          } else if (landmark.alternativeWalks != null && landmark.alternativeWalks!.containsKey(station.id)) {
            final walk = landmark.alternativeWalks![station.id]!;
            walkingPath = walk.walkingPath;
            walkMinutes = walk.walkingMinutes;
            final exits = repo.getExitsForStation(station.id);
            exit = exits.firstWhere(
              (e) => e.exitCode == walk.exitCode,
              orElse: () => station.findClosestExit(repo.exits, landmark.routeLat, landmark.routeLng),
            );
          }
        }

        exit ??= st?.findClosestExit(repo.exits, destination.lat, destination.lng);
        walkingPath ??= [LatLng(origin.lat, origin.lng), LatLng(destination.lat, destination.lng)];

        final walkSegment = RouteSegment(
          lineId: 'WALK',
          lineName: 'Walk',
          direction: 'Walk to destination',
          boundIndex: 0,
          fromStation: origin,
          toStation: destination,
          stationCount: 0,
          estimatedMinutes: walkMinutes > 0 ? walkMinutes : 5.0,
          fareThb: 0,
          standardFareThb: 0,
          walkingPath: walkingPath,
          exit: exit,
        );

        routeResult = RouteResult(
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
      } else {
        // Run Dijkstra on transit stations
        final result = repo.findRoute(originStationId, destinationStationId);

        if (result == null) {
          state = state.copyWith(
            isCalculating: false,
            error: t.errors.errorNoRoute,
          );
          return;
        }

        // Build RouteResult from DijkstraResult
        routeResult = _buildRouteResult(result, origin, destination, repo, fareService);
      }

      // Calculate saver route if available
      final saverRoute = _findSaverRoute(origin, destination, routeResult, repo, fareService);

      state = state.copyWith(
        routeResult: routeResult,
        regularRoute: routeResult,
        saverRoute: saverRoute,
        activeRouteType: 'recommended',
        isCalculating: false,
      );

      // Hydrate walking paths asynchronously in the background
      _hydrateAllRoutes(routeResult, saverRoute);
    } catch (e) {
      state = state.copyWith(
        isCalculating: false,
        error: t.errors.errorFailed(e.toString()),
      );
    }
  }

  /// Select active route type ('recommended' or 'saver')
  void selectRouteType(String type) {
    if (type == 'recommended') {
      state = state.copyWith(
        activeRouteType: 'recommended',
        routeResult: state.regularRoute,
      );
    } else if (type == 'saver') {
      state = state.copyWith(
        activeRouteType: 'saver',
        routeResult: state.saverRoute,
      );
    }
  }

  /// Calculate a cheaper/fewer transfers alternative route (Saver option)
  RouteResult? _findSaverRoute(
    SearchableItem origin,
    SearchableItem destination,
    RouteResult regularRoute,
    dynamic repo,
    FareService fareService,
  ) {
    // Only search for saver options if there is an active transit segment
    if (regularRoute.segments.isEmpty || regularRoute.segments.every((s) => s.lineId == 'WALK')) {
      return null;
    }

    final originStationId = origin.nearestStationId ?? origin.id;
    final destinationStationId = destination.nearestStationId ?? destination.id;

    final destLat = destination.lat;
    final destLng = destination.lng;
    final originLat = origin.lat;
    final originLng = origin.lng;

    final candidateDestStations = <Station>[];
    for (final station in repo.stations) {
      if (station.id == destinationStationId) continue;
      
      final dist = Geolocator.distanceBetween(destLat, destLng, station.lat, station.lng);
      // Look for alternative stations within 700 meters
      if (dist <= 700.0) {
        candidateDestStations.add(station);
      }
    }

    final candidateOriginStations = <Station>[];
    for (final station in repo.stations) {
      if (station.id == originStationId) continue;
      
      final dist = Geolocator.distanceBetween(originLat, originLng, station.lat, station.lng);
      // Look for alternative origin stations within 700 meters
      if (dist <= 700.0) {
        candidateOriginStations.add(station);
      }
    }

    RouteResult? bestSaverRoute;

    void evaluateCandidate(String startId, String endId, double startWalkMin, double endWalkMin) {
      final dijkstraResult = repo.findRoute(startId, endId);
      if (dijkstraResult == null) return;

      final tempOrigin = CustomLocation(
        id: origin.id,
        nameTh: origin.nameTh,
        nameEn: origin.nameEn,
        nearestStationId: startId,
        walkingMinutes: startWalkMin,
        lat: originLat,
        lng: originLng,
      );

      final tempDest = CustomLocation(
        id: destination.id,
        nameTh: destination.nameTh,
        nameEn: destination.nameEn,
        nearestStationId: endId,
        walkingMinutes: endWalkMin,
        lat: destLat,
        lng: destLng,
      );

      final altRoute = _buildRouteResult(dijkstraResult, tempOrigin, tempDest, repo, fareService);

      // Criteria for Saver Route:
      // 1. Lower fare than recommended route
      // 2. Must not be excessively slow (<= 15 minutes slower than regular)
      final isCheaper = altRoute.totalFareThb < regularRoute.totalFareThb;
      final isNotTooSlow = altRoute.totalMinutes <= regularRoute.totalMinutes + 15.0;

      if (isCheaper && isNotTooSlow) {
        final currentBest = bestSaverRoute;
        if (currentBest == null || 
            altRoute.totalFareThb < currentBest.totalFareThb ||
            (altRoute.totalFareThb == currentBest.totalFareThb && altRoute.transferCount < currentBest.transferCount)) {
          bestSaverRoute = altRoute;
        }
      }
    }

    // 1. Alternative destination stations
    for (final altDest in candidateDestStations) {
      final dist = Geolocator.distanceBetween(destLat, destLng, altDest.lat, altDest.lng);
      final walkMinutes = (dist / 80.0).clamp(1.0, 30.0);
      final originWalkMin = origin.walkingMinutes ?? 0.0;
      evaluateCandidate(originStationId, altDest.id, originWalkMin, walkMinutes);
    }

    // 2. Alternative origin stations
    for (final altOrigin in candidateOriginStations) {
      final dist = Geolocator.distanceBetween(originLat, originLng, altOrigin.lat, altOrigin.lng);
      final walkMinutes = (dist / 80.0).clamp(1.0, 30.0);
      final destWalkMin = destination.walkingMinutes ?? 0.0;
      evaluateCandidate(altOrigin.id, destinationStationId, walkMinutes, destWalkMin);
    }

    // 3. Alternative both origin and destination stations
    for (final altOrigin in candidateOriginStations) {
      final distOrigin = Geolocator.distanceBetween(originLat, originLng, altOrigin.lat, altOrigin.lng);
      final originWalkMin = (distOrigin / 80.0).clamp(1.0, 30.0);

      for (final altDest in candidateDestStations) {
        final distDest = Geolocator.distanceBetween(destLat, destLng, altDest.lat, altDest.lng);
        final destWalkMin = (distDest / 80.0).clamp(1.0, 30.0);

        evaluateCandidate(altOrigin.id, altDest.id, originWalkMin, destWalkMin);
      }
    }

    return bestSaverRoute;
  }

  RouteResult _buildRouteResult(
    DijkstraResult dijkstraResult,
    SearchableItem origin,
    SearchableItem destination,
    dynamic repo,
    FareService fareService,
  ) {
    final segments = <RouteSegment>[];
    final transfers = <TransferStep>[];
    final cardState = ref.read(userCardsProvider);

    // ─── 1. If Origin requires walking, add initial Walk Segment ───
    if (origin.nearestStationId != null) {
      final nearestStation = repo.getStation(origin.nearestStationId!) as Station?;
      if (nearestStation != null) {
        StationExit? exit;
        List<LatLng>? walkingPath;
        double walkingMinutes = origin.walkingMinutes ?? 5.0;

        Landmark? originLandmark;
        if (origin is Landmark) {
          originLandmark = origin;
        } else {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == origin.id && l is Landmark) {
              originLandmark = l;
              break;
            }
          }
        }

        if (originLandmark != null) {
          if (nearestStation.id == originLandmark.nearestStationId && originLandmark.walkingPath != null) {
            walkingPath = originLandmark.walkingPath;
            if (originLandmark.exitCode != null) {
              final exits = repo.getExitsForStation(nearestStation.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == originLandmark!.exitCode,
                orElse: () => nearestStation.findClosestExit(repo.exits, originLandmark!.routeLat, originLandmark.routeLng),
              );
            }
          } else if (originLandmark.alternativeWalks != null && originLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
            final walk = originLandmark.alternativeWalks![nearestStation.id]!;
            walkingPath = walk.walkingPath;
            walkingMinutes = walk.walkingMinutes;
            final exits = repo.getExitsForStation(nearestStation.id);
            exit = exits.firstWhere(
              (e) => e.exitCode == walk.exitCode,
              orElse: () => nearestStation.findClosestExit(repo.exits, originLandmark!.routeLat, originLandmark.routeLng),
            );
          }
        }

        exit ??= nearestStation.findClosestExit(repo.exits, originLandmark?.routeLat ?? origin.lat, originLandmark?.routeLng ?? origin.lng);
        walkingPath ??= [LatLng(originLandmark?.routeLat ?? origin.lat, originLandmark?.routeLng ?? origin.lng), LatLng(exit.lat, exit.lng)];

        segments.add(RouteSegment(
          lineId: 'WALK',
          lineName: 'Walk',
          direction: 'Walk to station',
          boundIndex: 0,
          fromStation: origin,
          toStation: nearestStation,
          stationCount: 0,
          estimatedMinutes: walkingMinutes,
          fareThb: 0,
          standardFareThb: 0,
          walkingPath: walkingPath,
          exit: exit,
        ));
      }
    }

    // Group path steps by line
    String currentLineId = '';
    Station? segmentStart;
    final segmentStations = <Station>[];

    for (int i = 0; i < dijkstraResult.path.length; i++) {
      final step = dijkstraResult.path[i];
      final station = repo.getStation(step.stationId) as Station?;
      if (station == null) continue;

      if (step.lineId == 'TRANSFER') {
        // End current segment
        if (segmentStart != null && segmentStations.length > 1) {
          final line = repo.getLine(currentLineId);
          final stationCount = segmentStations.length - 1;
          final bound = line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

          final standardFare = fareService.calculateFare(
            currentLineId,
            stationCount,
          );
          final discountedFare = fareService.calculateFare(
            currentLineId,
            stationCount,
            btsCardType: cardState.btsCardType,
            mrtCardType: cardState.mrtCardType,
            arlCardType: cardState.arlCardType,
          );

          segments.add(RouteSegment(
            lineId: currentLineId,
            lineName: line?.nameEn ?? currentLineId,
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

        // Record transfer
        if (segmentStations.isNotEmpty) {
          final nextLineId = i + 1 < dijkstraResult.path.length ? dijkstraResult.path[i + 1].lineId : '';
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
        currentLineId = i + 1 < dijkstraResult.path.length ? dijkstraResult.path[i + 1].lineId : '';
        continue;
      }

      if (step.lineId.isNotEmpty && step.lineId != currentLineId) {
        if (currentLineId.isEmpty) {
          currentLineId = step.lineId;
        } else {
          // Start of a new segment on a different line
          if (segmentStart != null && segmentStations.length > 1) {
            final line = repo.getLine(currentLineId);
            final stationCount = segmentStations.length - 1;
            final bound = line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

            final standardFare = fareService.calculateFare(
              currentLineId,
              stationCount,
            );
            final discountedFare = fareService.calculateFare(
              currentLineId,
              stationCount,
              btsCardType: cardState.btsCardType,
              mrtCardType: cardState.mrtCardType,
              arlCardType: cardState.arlCardType,
            );

            segments.add(RouteSegment(
              lineId: currentLineId,
              lineName: line?.nameEn ?? currentLineId,
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

    // Add last segment
    if (segmentStart != null && segmentStations.length > 1) {
      final line = repo.getLine(currentLineId);
      final stationCount = segmentStations.length - 1;
      final bound = line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

      final standardFare = fareService.calculateFare(
        currentLineId,
        stationCount,
      );
      final discountedFare = fareService.calculateFare(
        currentLineId,
        stationCount,
        btsCardType: cardState.btsCardType,
        mrtCardType: cardState.mrtCardType,
        arlCardType: cardState.arlCardType,
      );

      segments.add(RouteSegment(
        lineId: currentLineId,
        lineName: line?.nameEn ?? currentLineId,
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

    // ─── 2. If Destination requires walking, add final Walk Segment ───
    if (destination.nearestStationId != null) {
      final nearestStation = repo.getStation(destination.nearestStationId!) as Station?;
      if (nearestStation != null) {
        StationExit? exit;
        List<LatLng>? walkingPath;
        double walkingMinutes = destination.walkingMinutes ?? 5.0;

        Landmark? destLandmark;
        if (destination is Landmark) {
          destLandmark = destination;
        } else {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == destination.id && l is Landmark) {
              destLandmark = l;
              break;
            }
          }
        }

        if (destLandmark != null) {
          if (nearestStation.id == destLandmark.nearestStationId && destLandmark.walkingPath != null) {
            walkingPath = destLandmark.walkingPath;
            if (destLandmark.exitCode != null) {
              final exits = repo.getExitsForStation(nearestStation.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == destLandmark!.exitCode,
                orElse: () => nearestStation.findClosestExit(repo.exits, destLandmark!.routeLat, destLandmark.routeLng),
              );
            }
          } else if (destLandmark.alternativeWalks != null && destLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
            final walk = destLandmark.alternativeWalks![nearestStation.id]!;
            walkingPath = walk.walkingPath;
            walkingMinutes = walk.walkingMinutes;
            final exits = repo.getExitsForStation(nearestStation.id);
            exit = exits.firstWhere(
              (e) => e.exitCode == walk.exitCode,
              orElse: () => nearestStation.findClosestExit(repo.exits, destLandmark!.routeLat, destLandmark.routeLng),
            );
          }
        }

        exit ??= nearestStation.findClosestExit(repo.exits, destLandmark?.routeLat ?? destination.lat, destLandmark?.routeLng ?? destination.lng);
        walkingPath ??= [LatLng(exit.lat, exit.lng), LatLng(destLandmark?.routeLat ?? destination.lat, destLandmark?.routeLng ?? destination.lng)];

        segments.add(RouteSegment(
          lineId: 'WALK',
          lineName: 'Walk',
          direction: 'Walk to destination',
          boundIndex: 0,
          fromStation: nearestStation,
          toStation: destination,
          stationCount: 0,
          estimatedMinutes: walkingMinutes,
          fareThb: 0,
          standardFareThb: 0,
          walkingPath: walkingPath,
          exit: exit,
        ));
      }
    }

    final totalFare = segments.fold<int>(0, (sum, s) => sum + s.fareThb);
    final totalStandardFare = segments.fold<int>(0, (sum, s) => sum + s.standardFareThb);

    double totalMinutes = dijkstraResult.totalWeight;
    if (origin.walkingMinutes != null) totalMinutes += origin.walkingMinutes!;
    if (destination.walkingMinutes != null) totalMinutes += destination.walkingMinutes!;

    final totalStations = dijkstraResult.path.length - 1;

    return RouteResult(
      origin: origin,
      destination: destination,
      segments: segments,
      transfers: transfers,
      totalMinutes: totalMinutes,
      totalFareThb: totalFare,
      totalStandardFareThb: totalStandardFare,
      totalStations: totalStations,
      calculatedAt: DateTime.now(),
    );
  }

  /// Hydrates all routes asynchronously in the background
  Future<void> _hydrateAllRoutes(RouteResult recommended, RouteResult? saver) async {
    final hydratedRecommended = await _hydrateRouteWalkingPaths(recommended);
    RouteResult? hydratedSaver;
    if (saver != null) {
      hydratedSaver = await _hydrateRouteWalkingPaths(saver);
    }

    if (_mounted) {
      state = state.copyWith(
        routeResult: state.activeRouteType == 'recommended' ? hydratedRecommended : (hydratedSaver ?? state.routeResult),
        regularRoute: hydratedRecommended,
        saverRoute: hydratedSaver,
      );
    }
  }

  /// Asynchronously hydrates a RouteResult's walking segments with realistic OSRM paths
  Future<RouteResult> _hydrateRouteWalkingPaths(RouteResult route) async {
    final repo = ref.read(transitRepositoryProvider);
    final hydratedSegments = <RouteSegment>[];
    bool modified = false;

    for (final segment in route.segments) {
      if (segment.lineId == 'WALK') {
        final from = segment.fromStation;
        final to = segment.toStation;
        
        // Skip if it's already a precalculated landmark path
        bool isPrecalculated = false;
        Landmark? lm;
        Station? st;
        if (from is Landmark) {
          lm = from;
          if (to is Station) st = to;
        } else if (to is Landmark) {
          lm = to;
          if (from is Station) st = from;
        }

        if (lm == null) {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == from.id && l is Landmark) {
              lm = l;
              if (to is Station) st = to;
              break;
            } else if (l.id == to.id && l is Landmark) {
              lm = l;
              if (from is Station) st = from;
              break;
            }
          }
        }

        if (lm != null && st != null) {
          if (st.id == lm.nearestStationId && lm.walkingPath != null) {
            isPrecalculated = true;
          } else if (lm.alternativeWalks != null && lm.alternativeWalks!.containsKey(st.id)) {
            isPrecalculated = true;
          }
        }

        if (isPrecalculated) {
          hydratedSegments.add(segment);
          continue;
        }

        double fLat, fLng, tLat, tLng;
        final fromRouteLat = (lm != null && from.id == lm.id) ? lm.routeLat : from.lat;
        final fromRouteLng = (lm != null && from.id == lm.id) ? lm.routeLng : from.lng;
        final toRouteLat = (lm != null && to.id == lm.id) ? lm.routeLat : to.lat;
        final toRouteLng = (lm != null && to.id == lm.id) ? lm.routeLng : to.lng;

        if (segment.exit != null) {
          if (from is Station) {
            // Walk from station exit to destination
            fLat = segment.exit!.lat;
            fLng = segment.exit!.lng;
            tLat = toRouteLat;
            tLng = toRouteLng;
          } else {
            // Walk from origin to station exit
            fLat = fromRouteLat;
            fLng = fromRouteLng;
            tLat = segment.exit!.lat;
            tLng = segment.exit!.lng;
          }
        } else {
          // Direct walk
          fLat = fromRouteLat;
          fLng = fromRouteLng;
          tLat = toRouteLat;
          tLng = toRouteLng;
        }

        List<LatLng> path = await WalkingRouteService.getWalkingPath(fLat, fLng, tLat, tLng);

        // Detour Safety Guard: if OSRM returns a massive detour for a short straight-line distance,
        // override it with our smart L-shape Manhattan path.
        final straightDist = Geolocator.distanceBetween(fLat, fLng, tLat, tLng);
        if (straightDist < 400.0 && path.isNotEmpty) {
          double pathDist = 0.0;
          for (int idx = 0; idx < path.length - 1; idx++) {
            pathDist += Geolocator.distanceBetween(
              path[idx].latitude, path[idx].longitude,
              path[idx + 1].latitude, path[idx + 1].longitude,
            );
          }
          if (pathDist > 2.2 * straightDist) {
            print("OSRM detour detected (OSRM: ${pathDist.toStringAsFixed(1)}m, Straight: ${straightDist.toStringAsFixed(1)}m). Falling back to smart L-shape path.");
            path = WalkingRouteService.generateManhattanPath(fLat, fLng, tLat, tLng);
          }
        }
        
        hydratedSegments.add(RouteSegment(
          lineId: segment.lineId,
          lineName: segment.lineName,
          direction: segment.direction,
          boundIndex: segment.boundIndex,
          fromStation: segment.fromStation,
          toStation: segment.toStation,
          intermediateStations: segment.intermediateStations,
          stationCount: segment.stationCount,
          estimatedMinutes: segment.estimatedMinutes,
          fareThb: segment.fareThb,
          standardFareThb: segment.standardFareThb,
          walkingPath: path,
          exit: segment.exit,
        ));
        modified = true;
      } else {
        hydratedSegments.add(segment);
      }
    }

    if (modified) {
      return RouteResult(
        origin: route.origin,
        destination: route.destination,
        segments: hydratedSegments,
        transfers: route.transfers,
        totalMinutes: route.totalMinutes,
        totalFareThb: route.totalFareThb,
        totalStandardFareThb: route.totalStandardFareThb,
        totalStations: route.totalStations,
        calculatedAt: route.calculatedAt,
      );
    }
    return route;
  }
}


