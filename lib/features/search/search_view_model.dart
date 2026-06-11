import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/station.dart';
import '../../models/route_result.dart';
import '../../models/searchable_item.dart';
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
  final bool isCalculating;
  final String? error;

  const SearchState({
    this.query = '',
    this.searchResults = const [],
    this.origin,
    this.destination,
    this.routeResult,
    this.isCalculating = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchableItem>? searchResults,
    SearchableItem? origin,
    SearchableItem? destination,
    RouteResult? routeResult,
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

    if (origin == null || destination == null) return;
    if (origin.id == destination.id) {
      state = state.copyWith(error: 'ต้นทางและปลายทางเป็นสถานที่เดียวกัน');
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
            error: 'ไม่พบเส้นทาง',
          );
          return;
        }

        // Build RouteResult from DijkstraResult
        routeResult = _buildRouteResult(result, origin, destination, repo, fareService);
      }

      state = state.copyWith(
        routeResult: routeResult,
        isCalculating: false,
      );
    } catch (e) {
      state = state.copyWith(
        isCalculating: false,
        error: 'เกิดข้อผิดพลาด: $e',
      );
    }
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
