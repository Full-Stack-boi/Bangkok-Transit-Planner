import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:bkk_transit_planner/core/network/http_client_factory.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

class OsrmRouteResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng>? coordinates;

  OsrmRouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    this.coordinates,
  });
}

class OsrmService {
  final http.Client _client;

  OsrmService([http.Client? client]) : _client = client ?? http.Client();

  // Use HTTPS to prevent Mixed Content errors on Vercel/Production web
  static const String _baseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org/route/v1/foot',
  );

  /// Calculate walking route between two coordinates.
  /// If [fetchGeometry] is true, the response includes polyline coordinates.
  Future<OsrmRouteResult?> getWalkingRoute(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    bool fetchGeometry = false,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson&steps=false',
      );

      final response = await _client
          .get(url, headers: kDefaultHeaders)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();

          List<LatLng>? parsedCoords;
          if (fetchGeometry && route['geometry'] != null) {
            final coordsList = route['geometry']['coordinates'] as List;
            parsedCoords = coordsList.map((c) {
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();
          }

          return OsrmRouteResult(
            distanceMeters: distance,
            durationSeconds: duration,
            coordinates: parsedCoords,
          );
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('OSRM error: $e', error: e);
      return null;
    }
  }
}
