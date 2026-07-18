import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:bkk_transit_planner/core/network/http_client_factory.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';

/// Service for searching places online via Photon API (Elasticsearch-based autocomplete), bounded to Bangkok
class PhotonSearchService {
  final http.Client _client;
  final TransitRepository _repository;

  PhotonSearchService(this._repository, [http.Client? client])
      : _client = client ?? http.Client();

  Future<List<CustomLocation>> searchOnlinePlaces(String query) async {
    if (query.trim().length < 3) return [];

    try {
      // Query Photon API with Bangkok location bias (lat=13.7563, lon=100.5018)
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5&lat=13.7563&lon=100.5018&lang=en'
      );

      final response = await _client.get(
        uri,
        headers: kDefaultHeaders,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        final results = <CustomLocation>[];

        for (final item in features) {
          final geometry = item['geometry'] as Map<String, dynamic>?;
          final properties = item['properties'] as Map<String, dynamic>?;
          if (geometry == null || properties == null) continue;

          final coords = geometry['coordinates'] as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;

          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          if (lat == 0.0 || lon == 0.0) continue;

          final name = properties['name'] as String? ?? '';
          if (name.isEmpty) continue;

          final city = properties['city'] as String? ?? '';
          final state = properties['state'] as String? ?? '';

          // Explicitly exclude Phetchaburi Province to prevent it from being selectable
          final lowerName = name.toLowerCase();
          final lowerCity = city.toLowerCase();
          final lowerState = state.toLowerCase();
          if (lowerName.contains('จังหวัดเพชรบุรี') ||
              lowerCity.contains('จังหวัดเพชรบุรี') ||
              lowerState.contains('จังหวัดเพชรบุรี') ||
              lowerName.contains('phetchaburi') ||
              lowerCity.contains('phetchaburi') ||
              lowerState.contains('phetchaburi')) {
            continue;
          }

          // Find nearest station
          final nearest = _repository.findNearestStation(lat, lon);
          if (nearest != null) {
            final dist = Geolocator.distanceBetween(lat, lon, nearest.lat, nearest.lng);
            // Limit results to locations within 12 km of a transit station to filter out far-away provinces
            if (dist <= 12000.0) {
              // Walking minutes based on 80 meters/minute, capped between 1 and 30 mins
              final walkMin = (dist / 80.0).clamp(1.0, 30.0);

              final osmType = properties['osm_type'] as String? ?? 'N';
              final osmId = properties['osm_id'] ?? DateTime.now().millisecondsSinceEpoch;
              results.add(CustomLocation(
                id: 'OSM_${osmType}_${osmId}_${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}',
                nameTh: name,
                nameEn: name,
                nearestStationId: nearest.id,
                walkingMinutes: walkMin,
                lat: lat,
                lng: lon,
              ));
            }
          }
        }
        return results;
      }
    } catch (e) {
      AppLogger.error('Online place search failed: $e', error: e);
    }
    return [];
  }
}
