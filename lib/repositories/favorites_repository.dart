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
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
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
      'origin_lat': originLat?.toString() ?? '',
      'origin_lng': originLng?.toString() ?? '',
      'destination_lat': destinationLat?.toString() ?? '',
      'destination_lng': destinationLng?.toString() ?? '',
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

  /// Bidirectional sync: uploads local offline changes, and downloads remote changes
  Future<void> syncOfflineDataWithSupabase() async {
    await initialize();
    if (!_supabaseService.isInitialized) return;

    final client = _supabaseService.client;
    final user = client?.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Get local data
      final localFavs = getFavoriteStationIds();
      final localRoutes = getSavedRoutes();

      // 2. Upload local favorites to Supabase (upsert)
      if (localFavs.isNotEmpty) {
        final favsToInsert = localFavs.map((stationId) => {
          'user_id': user.id,
          'station_id': stationId,
        }).toList();
        
        await client?.from('user_favorites').upsert(favsToInsert);
      }

      // 3. Upload local saved routes to Supabase (upsert)
      if (localRoutes.isNotEmpty) {
        final routesToInsert = localRoutes.map((route) => {
          'user_id': user.id,
          'origin_id': route['origin_id'],
          'destination_id': route['destination_id'],
          'name': route['name'] ?? 'Route',
        }).toList();

        await client?.from('saved_routes').upsert(routesToInsert);
      }

      // 4. Download remote favorites from Supabase
      final remoteFavsResponse = await client?.from('user_favorites').select('station_id').eq('user_id', user.id);
      if (remoteFavsResponse != null) {
        final List<dynamic> remoteFavsData = remoteFavsResponse;
        final remoteFavs = remoteFavsData.map((item) => item['station_id'] as String).toList();
        
        // Merge with local favorites
        final mergedFavs = {...localFavs, ...remoteFavs}.toList();
        await _prefs?.setStringList('favorite_station_ids', mergedFavs);
      }

      // 5. Download remote saved routes from Supabase
      final remoteRoutesResponse = await client?.from('saved_routes').select().eq('user_id', user.id);
      if (remoteRoutesResponse != null) {
        final List<dynamic> remoteRoutesData = remoteRoutesResponse;
        
        // Convert to local map structure
        final remoteRoutes = remoteRoutesData.map((item) => {
          'origin_id': item['origin_id'] as String,
          'destination_id': item['destination_id'] as String,
          'origin_name': item['origin_name'] as String? ?? '',
          'destination_name': item['destination_name'] as String? ?? '',
          'name': item['name'] as String? ?? '',
          'created_at': item['created_at'] as String? ?? DateTime.now().toIso8601String(),
        }).toList();

        // Merge saved routes based on origin_id & destination_id
        final Map<String, Map<String, String>> mergedRoutesMap = {};
        
        // Add all local routes first
        for (final route in localRoutes) {
          final key = '${route['origin_id']}_${route['destination_id']}';
          mergedRoutesMap[key] = route;
        }
        
        // Overwrite/add with remote routes
        for (final route in remoteRoutes) {
          final key = '${route['origin_id']}_${route['destination_id']}';
          // Preserve local origin_name and destination_name if they are already present locally
          final existing = mergedRoutesMap[key];
          mergedRoutesMap[key] = {
            'origin_id': route['origin_id']!,
            'destination_id': route['destination_id']!,
            'origin_name': existing?['origin_name'] ?? route['origin_name'] ?? '',
            'destination_name': existing?['destination_name'] ?? route['destination_name'] ?? '',
            'origin_lat': existing?['origin_lat'] ?? '',
            'origin_lng': existing?['origin_lng'] ?? '',
            'destination_lat': existing?['destination_lat'] ?? '',
            'destination_lng': existing?['destination_lng'] ?? '',
            'name': route['name']!,
            'created_at': route['created_at']!,
          };
        }

        final mergedRoutes = mergedRoutesMap.values.toList();
        final serialized = mergedRoutes.map((item) => json.encode(item)).toList();
        await _prefs?.setStringList('saved_routes', serialized);
      }
    } catch (e) {
      print('Bidirectional Supabase sync failed: $e');
      rethrow;
    }
  }
}
