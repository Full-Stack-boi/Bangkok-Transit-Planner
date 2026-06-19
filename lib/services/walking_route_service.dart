import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart';

/// Service for generating realistic walking routes (online via OSRM, offline via Manhattan grid fallback)
class WalkingRouteService {
  /// Fetches a walking path from start coordinates to end coordinates
  static Future<List<LatLng>> getWalkingPath(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    final client = HttpClient();
    client.userAgent = 'com.bkktransit.bkk_transit_planner';

    try {
      final uri = Uri.parse(
        'http://router.project-osrm.org/route/v1/foot/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson'
      );

      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(body);

        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List<dynamic>;
          if (routes.isNotEmpty) {
            final geometry = routes[0]['geometry'] as Map<String, dynamic>;
            final coordinates = geometry['coordinates'] as List<dynamic>;

            final points = coordinates.map((c) {
              final lng = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();

            if (points.isNotEmpty) {
              return points;
            }
          }
        }
      }
    } catch (e) {
      print('OSRM walking path fetch failed: $e. Falling back to Manhattan grid path.');
    } finally {
      client.close();
    }

    // Offline / Error Fallback: Manhattan grid path
    return generateManhattanPath(fromLat, fromLng, toLat, toLng);
  }

  /// Generates a right-angle grid-like path between two points
  static List<LatLng> generateManhattanPath(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    final latDiff = (fromLat - toLat).abs();
    final lngDiff = (fromLng - toLng).abs();

    if (lngDiff > latDiff) {
      // Horizontal first (align with East-West main roads like Rama I / Sukhumvit)
      return [
        LatLng(fromLat, fromLng),
        LatLng(fromLat, toLng),
        LatLng(toLat, toLng),
      ];
    } else {
      // Vertical first (align with North-South main roads like Phaya Thai / Ratchadaphisek)
      return [
        LatLng(fromLat, fromLng),
        LatLng(toLat, fromLng),
        LatLng(toLat, toLng),
      ];
    }
  }
}
