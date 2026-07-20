import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Repository for managing user favorite stations and saved routes
class FavoritesRepository {
  final SupabaseService _supabaseService;
  SharedPreferences? _prefs;
  bool _initialized = false;

  FavoritesRepository(this._supabaseService);

  static const _favoritesKeyPrefix = 'favorite_station_ids_v2';
  static const _routesKeyPrefix = 'saved_routes_v2';

  /// Keeps local data separate for every signed-in account.
  ///
  /// The anonymous scope supports favorites used before a user signs in, while
  /// preventing one user's cached data from being read or uploaded for another.
  String get _storageScope =>
      _supabaseService.client?.auth.currentUser?.id ?? 'anonymous';

  String get _favoritesKey => '${_favoritesKeyPrefix}_$_storageScope';
  String get _routesKey => '${_routesKeyPrefix}_$_storageScope';

  /// Initialize SharedPreferences
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Favorite Stations

  /// Get list of favorite station IDs
  List<String> getFavoriteStationIds() {
    return _prefs?.getStringList(_favoritesKey) ?? [];
  }

  /// Toggle favorite status of a station (returns true if now favorited, false if removed)
  Future<bool> toggleFavoriteStation(String stationId) async {
    await initialize();
    final list = getFavoriteStationIds();
    final isFav = list.contains(stationId);
    final newList = List<String>.from(list);

    if (isFav) {
      newList.remove(stationId);
    } else {
      newList.add(stationId);
    }

    await _prefs?.setStringList(_favoritesKey, newList);

    // Sync with Supabase in background (try-catch, fail silently)
    if (_supabaseService.isInitialized) {
      try {
        final client = _supabaseService.client;
        final user = client?.auth.currentUser;
        if (user != null) {
          if (isFav) {
            await client?.from('user_favorites').delete().match({
              'user_id': user.id,
              'station_id': stationId,
            });
          } else {
            await client?.from('user_favorites').upsert({
              'user_id': user.id,
              'station_id': stationId,
            }, onConflict: 'user_id,station_id');
          }
        }
      } catch (e) {
        AppLogger.error('Supabase favorites sync failed: $e', error: e);
      }
    }

    return !isFav;
  }

  /// Check if a station is favorited
  bool isFavoriteStation(String stationId) {
    return getFavoriteStationIds().contains(stationId);
  }

  // Saved Routes

  /// Get list of saved routes as maps
  List<Map<String, String>> getSavedRoutes() {
    final list = _prefs?.getStringList(_routesKey) ?? [];
    return list.map((item) {
      final decoded = json.decode(item) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    }).toList();
  }

  /// Save a route
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
    await initialize();
    final list = getSavedRoutes();

    // Remove existing if same endpoints
    final filtered = list
        .where(
          (item) =>
              !(item['origin_id'] == originId &&
                  item['destination_id'] == destinationId),
        )
        .toList();

    filtered.add({
      'origin_id': originId,
      'destination_id': destinationId,
      'origin_name': originName,
      'destination_name': destinationName,
      'name': routeName,
      'origin_lat': originLat?.toString() ?? '',
      'origin_lng': originLng?.toString() ?? '',
      'destination_lat': destinationLat?.toString() ?? '',
      'destination_lng': destinationLng?.toString() ?? '',
      'created_at': DateTime.now().toIso8601String(),
    });

    final serialized = filtered.map((item) => json.encode(item)).toList();
    await _prefs?.setStringList(_routesKey, serialized);

    // Sync with Supabase in background
    if (_supabaseService.isInitialized) {
      try {
        final client = _supabaseService.client;
        final user = client?.auth.currentUser;
        if (user != null) {
          await client?.from('saved_routes').upsert({
            'user_id': user.id,
            'origin_id': originId,
            'destination_id': destinationId,
            'name': routeName,
          }, onConflict: 'user_id,origin_id,destination_id');
        }
      } catch (e) {
        AppLogger.error('Supabase route sync failed: $e', error: e);
      }
    }
  }

  /// Delete a saved route
  Future<void> deleteRoute(String originId, String destinationId) async {
    await initialize();
    final list = getSavedRoutes();
    final filtered = list
        .where(
          (item) =>
              !(item['origin_id'] == originId &&
                  item['destination_id'] == destinationId),
        )
        .toList();

    final serialized = filtered.map((item) => json.encode(item)).toList();
    await _prefs?.setStringList(_routesKey, serialized);

    // Sync with Supabase in background
    if (_supabaseService.isInitialized) {
      try {
        final client = _supabaseService.client;
        final user = client?.auth.currentUser;
        if (user != null) {
          await client?.from('saved_routes').delete().match({
            'user_id': user.id,
            'origin_id': originId,
            'destination_id': destinationId,
          });
        }
      } catch (e) {
        AppLogger.error('Supabase route deletion sync failed: $e', error: e);
      }
    }
  }

  /// Check if a route is saved
  bool isRouteSaved(String originId, String destinationId) {
    return getSavedRoutes().any(
      (item) =>
          item['origin_id'] == originId &&
          item['destination_id'] == destinationId,
    );
  }

  /// Refreshes the current user's local cache from Supabase.
  ///
  /// Mutations are synced immediately by save/delete/toggle methods. At login,
  /// Supabase is the source of truth so a stale device cache cannot recreate a
  /// route or favorite deleted from another device or account.
  Future<void> syncOfflineDataWithSupabase() async {
    await initialize();
    if (!_supabaseService.isInitialized) return;

    final client = _supabaseService.client;
    final user = client?.auth.currentUser;
    if (user == null) return;

    try {
      // Keep matching route metadata that is not currently stored remotely,
      // such as custom-location coordinates used for route restoration.
      final localRoutes = getSavedRoutes();

      // Download remote favorites and replace this user's local cache.
      final remoteFavsResponse = await client
          ?.from('user_favorites')
          .select('station_id')
          .eq('user_id', user.id);
      if (remoteFavsResponse != null) {
        final List<dynamic> remoteFavsData = remoteFavsResponse;
        final remoteFavs = remoteFavsData
            .map((item) => item['station_id'] as String)
            .toList();
        await _prefs?.setStringList(_favoritesKey, remoteFavs);
      }

      // Download remote routes and replace this user's local cache.
      final remoteRoutesResponse = await client
          ?.from('saved_routes')
          .select()
          .eq('user_id', user.id);
      if (remoteRoutesResponse != null) {
        final List<dynamic> remoteRoutesData = remoteRoutesResponse;

        // Convert to local map structure
        final remoteRoutes = remoteRoutesData
            .map(
              (item) => {
                'origin_id': item['origin_id'] as String,
                'destination_id': item['destination_id'] as String,
                'origin_name': item['origin_name'] as String? ?? '',
                'destination_name': item['destination_name'] as String? ?? '',
                'name': item['name'] as String? ?? '',
                'created_at':
                    item['created_at'] as String? ??
                    DateTime.now().toIso8601String(),
              },
            )
            .toList();

        final localRoutesByKey = <String, Map<String, String>>{};
        for (final route in localRoutes) {
          final key = '${route['origin_id']}_${route['destination_id']}';
          localRoutesByKey[key] = route;
        }

        final synchronizedRoutes = <Map<String, String>>[];
        for (final route in remoteRoutes) {
          final key = '${route['origin_id']}_${route['destination_id']}';
          final existing = localRoutesByKey[key];
          synchronizedRoutes.add({
            'origin_id': route['origin_id']!,
            'destination_id': route['destination_id']!,
            'origin_name':
                existing?['origin_name'] ?? route['origin_name'] ?? '',
            'destination_name':
                existing?['destination_name'] ??
                route['destination_name'] ??
                '',
            'origin_lat': existing?['origin_lat'] ?? '',
            'origin_lng': existing?['origin_lng'] ?? '',
            'destination_lat': existing?['destination_lat'] ?? '',
            'destination_lng': existing?['destination_lng'] ?? '',
            'name': route['name']!,
            'created_at': route['created_at']!,
          });
        }

        final serialized = synchronizedRoutes
            .map((item) => json.encode(item))
            .toList();
        await _prefs?.setStringList(_routesKey, serialized);
      }
    } catch (e) {
      AppLogger.error('Bidirectional Supabase sync failed: $e', error: e);
      rethrow;
    }
  }
}
