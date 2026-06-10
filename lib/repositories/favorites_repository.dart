import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

/// Repository for managing user favorite stations and saved routes
class FavoritesRepository {
  final SupabaseService _supabaseService;
  SharedPreferences? _prefs;
  bool _initialized = false;

  FavoritesRepository(this._supabaseService);

  /// Initialize SharedPreferences
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ─── Favorite Stations ───

  /// Get list of favorite station IDs
  List<String> getFavoriteStationIds() {
    return _prefs?.getStringList('favorite_station_ids') ?? [];
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

    await _prefs?.setStringList('favorite_station_ids', newList);

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
            await client?.from('user_favorites').insert({
              'user_id': user.id,
              'station_id': stationId,
            });
          }
        }
      } catch (e) {
        print('Supabase favorites sync failed: $e');
      }
    }

    return !isFav;
  }

  /// Check if a station is favorited
  bool isFavoriteStation(String stationId) {
    return getFavoriteStationIds().contains(stationId);
  }

  // ─── Saved Routes ───

  /// Get list of saved routes as maps
  List<Map<String, String>> getSavedRoutes() {
    final list = _prefs?.getStringList('saved_routes') ?? [];
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
  }) async {
    await initialize();
    final list = getSavedRoutes();

    // Remove existing if same endpoints
    final filtered = list.where((item) =>
        !(item['origin_id'] == originId && item['destination_id'] == destinationId)).toList();

    filtered.add({
      'origin_id': originId,
      'destination_id': destinationId,
      'origin_name': originName,
      'destination_name': destinationName,
      'name': routeName,
      'created_at': DateTime.now().toIso8601String(),
    });

    final serialized = filtered.map((item) => json.encode(item)).toList();
    await _prefs?.setStringList('saved_routes', serialized);

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
          });
        }
      } catch (e) {
        print('Supabase route sync failed: $e');
      }
    }
  }

  /// Delete a saved route
  Future<void> deleteRoute(String originId, String destinationId) async {
    await initialize();
    final list = getSavedRoutes();
    final filtered = list.where((item) =>
        !(item['origin_id'] == originId && item['destination_id'] == destinationId)).toList();

    final serialized = filtered.map((item) => json.encode(item)).toList();
    await _prefs?.setStringList('saved_routes', serialized);

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
        print('Supabase route deletion sync failed: $e');
      }
    }
  }

  /// Check if a route is saved
  bool isRouteSaved(String originId, String destinationId) {
    return getSavedRoutes().any((item) =>
        item['origin_id'] == originId && item['destination_id'] == destinationId);
  }
}
