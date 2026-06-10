import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/station.dart';
import '../../models/route_result.dart';
import '../../providers/providers.dart';
import '../../services/dijkstra_planner.dart';
import '../../services/fare_service.dart';
import '../../core/constants/transit_constants.dart';

/// State for search feature
class SearchState {
  final String query;
  final List<Station> searchResults;
  final Station? origin;
  final Station? destination;
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
    List<Station>? searchResults,
    Station? origin,
    Station? destination,
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

  /// Search stations by query
  void search(String query) {
    final repo = _ref.read(transitRepositoryProvider);
    final results = repo.searchStations(query);
    state = state.copyWith(
      query: query,
      searchResults: results,
      clearError: true,
    );
  }

  /// Set origin station
  void setOrigin(Station station) {
    state = state.copyWith(
      origin: station,
      clearRoute: true,
      clearError: true,
    );
    _tryCalculateRoute();
  }

  /// Set destination station
  void setDestination(Station station) {
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
      state = state.copyWith(error: 'ต้นทางและปลายทางเป็นสถานีเดียวกัน');
      return;
    }

    state = state.copyWith(isCalculating: true, clearError: true);

    try {
      final repo = _ref.read(transitRepositoryProvider);
      final fareService = _ref.read(fareServiceProvider);
      final result = repo.findRoute(origin.id, destination.id);

      if (result == null) {
        state = state.copyWith(
          isCalculating: false,
          error: 'ไม่พบเส้นทาง',
        );
        return;
      }

      // Build RouteResult from DijkstraResult
      final routeResult = _buildRouteResult(result, origin, destination, repo, fareService);
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
    Station origin,
    Station destination,
    dynamic repo,
    FareService fareService,
  ) {
    final segments = <RouteSegment>[];
    final transfers = <TransferStep>[];

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

    final totalFare = segments.fold<int>(0, (sum, s) => sum + s.fareThb);
    final totalMinutes = dijkstraResult.totalWeight;
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
