import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/station.dart';
import '../../models/route_result.dart';
import '../../models/searchable_item.dart';
import '../../models/custom_location.dart';
import '../../providers/providers.dart';
import '../../services/dijkstra_planner.dart';
import '../../services/fare_service.dart';
import '../../core/constants/transit_constants.dart';

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
class SearchViewModel extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchViewModel(this._ref) : super(const SearchState());

  /// Search stations and landmarks by query, querying online places if needed
  Future<void> search(String query) async {
    state = state.copyWith(query: query, clearError: true);

    final repo = _ref.read(transitRepositoryProvider);

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
    final t = _ref.read(translationsProvider);

    if (origin == null || destination == null) return;
    if (origin.id == destination.id) {
      state = state.copyWith(error: t.errors.errorSamePlaces);
      return;
    }

    state = state.copyWith(isCalculating: true, clearError: true);

    try {
      final repo = _ref.read(transitRepositoryProvider);
      final fareService = _ref.read(fareServiceProvider);

      final originStationId = origin.nearestStationId ?? origin.id;
      final destinationStationId = destination.nearestStationId ?? destination.id;

      RouteResult routeResult;

      if (originStationId == destinationStationId) {
        // Direct walk scenario (e.g. between landmarks near same station, or landmark and its station)
        final walkMinutes = (origin.walkingMinutes ?? 0.0) + (destination.walkingMinutes ?? 0.0);
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
        );

        routeResult = RouteResult(
          origin: origin,
          destination: destination,
          segments: [walkSegment],
          transfers: [],
          totalMinutes: walkMinutes > 0 ? walkMinutes : 5.0,
          totalFareThb: 0,
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

    // ─── 1. If Origin requires walking, add initial Walk Segment ───
    if (origin.nearestStationId != null) {
      final nearestStation = repo.getStation(origin.nearestStationId!) as Station?;
      if (nearestStation != null) {
        segments.add(RouteSegment(
          lineId: 'WALK',
          lineName: 'Walk',
          direction: 'Walk to station',
          boundIndex: 0,
          fromStation: origin,
          toStation: nearestStation,
          stationCount: 0,
          estimatedMinutes: origin.walkingMinutes ?? 5.0,
          fareThb: 0,
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
            fareThb: fareService.calculateFare(currentLineId, stationCount),
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
              fareThb: fareService.calculateFare(currentLineId, stationCount),
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
        fareThb: fareService.calculateFare(currentLineId, stationCount),
      ));
    }

    // ─── 2. If Destination requires walking, add final Walk Segment ───
    if (destination.nearestStationId != null) {
      final nearestStation = repo.getStation(destination.nearestStationId!) as Station?;
      if (nearestStation != null) {
        segments.add(RouteSegment(
          lineId: 'WALK',
          lineName: 'Walk',
          direction: 'Walk to destination',
          boundIndex: 0,
          fromStation: nearestStation,
          toStation: destination,
          stationCount: 0,
          estimatedMinutes: destination.walkingMinutes ?? 5.0,
          fareThb: 0,
        ));
      }
    }

    final totalFare = segments.fold<int>(0, (sum, s) => sum + s.fareThb);
    
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
      totalStations: totalStations,
      calculatedAt: DateTime.now(),
    );
  }
}

// ─── Provider ───

final searchViewModelProvider =
    StateNotifierProvider<SearchViewModel, SearchState>((ref) {
  return SearchViewModel(ref);
});
