import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/station.dart';
import '../../providers/providers.dart';

part 'favorites_view_model.g.dart';

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
@riverpod
class FavoritesViewModel extends _$FavoritesViewModel {
  @override
  FavoritesState build() {
    return _getFavoritesState();
  }

  FavoritesState _getFavoritesState() {
    final repo = ref.read(favoritesRepositoryProvider);
    final transitRepo = ref.read(transitRepositoryProvider);

    final favoriteIds = repo.getFavoriteStationIds();
    final favoriteStations = favoriteIds
        .map((id) => transitRepo.getStation(id))
        .whereType<Station>()
        .toList();

    final savedRoutes = repo.getSavedRoutes();

    return FavoritesState(
      favoriteStations: favoriteStations,
      savedRoutes: savedRoutes,
    );
  }

  /// Reload favorites and saved routes from repository
  void refresh() {
    state = _getFavoritesState();
  }

  /// Toggle favorite station
  Future<void> toggleFavoriteStation(String stationId) async {
    final repo = ref.read(favoritesRepositoryProvider);
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
    final repo = ref.read(favoritesRepositoryProvider);
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
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.deleteRoute(originId, destinationId);
    refresh();
  }
}
