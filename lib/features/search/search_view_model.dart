import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/route_result.dart';
import '../../models/searchable_item.dart';
import '../../providers/providers.dart';
import 'place_resolver.dart';
import 'route_calculator.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

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
  final bool isSearching;
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
    this.isSearching = false,
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
    bool? isSearching,
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
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ViewModel for search feature — orchestrates search, place resolution, and route calculation.
/// Heavy logic is delegated to [PlaceResolver] and [RouteCalculator].
@Riverpod(keepAlive: true)
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

  //  Search

  /// Search stations and landmarks by query, querying online places if needed
  Future<void> search(String query) async {
    state = state.copyWith(query: query, clearError: true);

    final repo = ref.read(transitRepositoryProvider);

    // Trigger Namtang stops loading if it hasn't started yet
    repo.loadNamtangStops();

    // 1. Search local places (stations + landmarks) instantly
    final localResults = repo.searchLocalPlaces(query);
    state = state.copyWith(searchResults: localResults);

    if (query.trim().length >= 3) {
      // 2. Fetch online places in background
      state = state.copyWith(isSearching: true);
      try {
        final photonService = ref.read(photonSearchServiceProvider);
        final onlineResults = await photonService.searchOnlinePlaces(query);

        // Merge without duplicates (O(n) using Sets for fast lookup)
        if (state.query == query) {
          final merged = [...localResults];
          final seenNames = {
            for (final item in localResults) item.nameTh.toLowerCase(),
          };
          final seenCoords = {
            for (final item in localResults) '${item.lat},${item.lng}',
          };

          for (final online in onlineResults) {
            final name = online.nameTh.toLowerCase();
            final coords = '${online.lat},${online.lng}';

            if (!seenNames.contains(name) && !seenCoords.contains(coords)) {
              merged.add(online);
              seenNames.add(name);
              seenCoords.add(coords);
            }
          }
          state = state.copyWith(searchResults: merged, isSearching: false);
        }
      } catch (e) {
        AppLogger.error('Online place search failed: $e', error: e);
        if (state.query == query) {
          state = state.copyWith(isSearching: false);
        }
      }
    } else {
      state = state.copyWith(isSearching: false);
    }
  }

  //  Origin / Destination

  /// Set origin station or place
  Future<void> setOrigin(SearchableItem station) async {
    final resolver = PlaceResolver(ref.read(transitRepositoryProvider));
    state = state.copyWith(isCalculating: true, clearError: true);
    final resolved = await resolver.resolve(station);
    if (!_mounted) return;
    state = state.copyWith(
      origin: resolved,
      clearRoute: true,
      clearError: true,
      isCalculating: false,
    );
    _tryCalculateRoute();
  }

  /// Set destination station or place
  Future<void> setDestination(SearchableItem station) async {
    final resolver = PlaceResolver(ref.read(transitRepositoryProvider));
    state = state.copyWith(isCalculating: true, clearError: true);
    final resolved = await resolver.resolve(station);
    if (!_mounted) return;
    state = state.copyWith(
      destination: resolved,
      clearRoute: true,
      clearError: true,
      isCalculating: false,
    );
    _tryCalculateRoute();
  }

  /// Set both origin and destination at the same time (e.g. from saved routes)
  Future<void> setRoute(
    SearchableItem origin,
    SearchableItem destination,
  ) async {
    try {
      final resolver = PlaceResolver(ref.read(transitRepositoryProvider));
      state = state.copyWith(isCalculating: true, clearError: true);
      final results = await Future.wait([
        resolver.resolve(origin),
        resolver.resolve(destination),
      ]);
      if (!_mounted) return;
      state = state.copyWith(
        origin: results[0],
        destination: results[1],
        clearRoute: true,
        clearError: true,
        isCalculating: false,
      );
      _tryCalculateRoute();
    } catch (e, stack) {
      AppLogger.error('Error in setRoute: $e\n$stack', error: e);
      if (_mounted) {
        state = state.copyWith(isCalculating: false, error: e.toString());
      }
    }
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

  //  Route Calculation (delegated to RouteCalculator)

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
      final httpClient = ref.read(httpClientProvider);

      final calculator = RouteCalculator(repo, fareService, httpClient);
      final cardState = ref.read(userCardsProvider);
      final translations = RouteTranslations(
        walkToStation: t.routeResult.walkToStation,
        walkToDestination: t.routeResult.walkToDestination,
        errorSamePlaces: t.errors.errorSamePlaces,
        errorNoRoute: t.errors.errorNoRoute,
        errorFailed: t.errors.errorFailed,
      );
      final cardSnapshot = CardStateSnapshot(
        btsCardType: cardState.btsCardType,
        mrtCardType: cardState.mrtCardType,
        arlCardType: cardState.arlCardType,
        srtCardType: cardState.srtCardType,
      );

      final result = calculator.calculate(
        origin,
        destination,
        cardSnapshot,
        translations,
      );

      if (result == null) {
        state = state.copyWith(
          isCalculating: false,
          error: t.errors.errorNoRoute,
        );
        return;
      }

      state = state.copyWith(
        routeResult: result.recommended,
        regularRoute: result.recommended,
        saverRoute: result.saver,
        activeRouteType: 'recommended',
        isCalculating: false,
      );

      // Hydrate walking paths asynchronously in the background
      _hydrateAllRoutes(calculator, result.recommended, result.saver);
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

  //  Background Hydration

  Future<void> _hydrateAllRoutes(
    RouteCalculator calculator,
    RouteResult recommended,
    RouteResult? saver,
  ) async {
    try {
      final (hydratedRecommended, hydratedSaver) = await calculator
          .hydrateRoutes(recommended, saver);

      if (_mounted &&
          state.origin != null &&
          state.destination != null &&
          state.origin!.id == recommended.origin.id &&
          state.destination!.id == recommended.destination.id) {
        state = state.copyWith(
          routeResult: state.activeRouteType == 'recommended'
              ? hydratedRecommended
              : (hydratedSaver ?? state.routeResult),
          regularRoute: hydratedRecommended,
          saverRoute: hydratedSaver,
        );
      }
    } catch (e, stack) {
      AppLogger.error('Error hydrating walking paths: $e\n$stack', error: e);
    }
  }
}
