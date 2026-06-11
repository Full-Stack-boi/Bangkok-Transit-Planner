import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/station.dart';
import '../../providers/providers.dart';

/// State for the favorites screen
class FavoritesState {
  final List<Station> favoriteStations;
  final List<Map<String, String>> savedRoutes;

  const FavoritesState({
    this.favoriteStations = const [],
    this.savedRoutes = const [],
  });

  FavoritesState copyWith({
    List<Station>? favoriteStations,
    List<Map<String, String>>? savedRoutes,
  }) {
    return FavoritesState(
      favoriteStations: favoriteStations ?? this.favoriteStations,
      savedRoutes: savedRoutes ?? this.savedRoutes,
    );
  }
}

/// ViewModel for managing favorites and saved routes
class FavoritesViewModel extends StateNotifier<FavoritesState> {
  final Ref _ref;

  FavoritesViewModel(this._ref) : super(const FavoritesState()) {
    refresh();
  }

  /// Reload favorites and saved routes from repository
  void refresh() {
    final repo = _ref.read(favoritesRepositoryProvider);
    final transitRepo = _ref.read(transitRepositoryProvider);

    final favoriteIds = repo.getFavoriteStationIds();
    final favoriteStations = favoriteIds
        .map((id) => transitRepo.getStation(id))
        .whereType<Station>()
        .toList();

    final savedRoutes = repo.getSavedRoutes();

    state = FavoritesState(
      favoriteStations: favoriteStations,
      savedRoutes: savedRoutes,
    );
  }

  /// Toggle favorite station
  Future<void> toggleFavoriteStation(String stationId) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    await repo.toggleFavoriteStation(stationId);
    refresh();
  }

  /// Save a new route
  Future<void> saveRoute({
    required String originId,
    required String destinationId,
    required String originName,
    required String destinationName,
    required String routeName,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    await repo.saveRoute(
      originId: originId,
      destinationId: destinationId,
      originName: originName,
      destinationName: destinationName,
      routeName: routeName,
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );
    refresh();
  }

  /// Delete a saved route
  Future<void> deleteRoute(String originId, String destinationId) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    await repo.deleteRoute(originId, destinationId);
    refresh();
  }
}

// ─── Provider ───

final favoritesViewModelProvider =
    StateNotifierProvider<FavoritesViewModel, FavoritesState>((ref) {
  return FavoritesViewModel(ref);
});
