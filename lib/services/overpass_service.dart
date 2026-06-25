import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OverpassService {
  final String _baseUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<LatLng>> findEntrances(
    double lat,
    double lon, {
    double radius = 150.0,
    String? osmType,
    int? osmId,
  }) async {
    String query;
    if (osmType != null &&
        osmId != null &&
        (osmType == 'W' || osmType == 'R')) {
      if (osmType == 'R') {
        query =
            '''
          [out:json][timeout:10];
          (
            relation($osmId);
            node(r)["barrier"];
            node(r)["entrance"];
            way(r);
            node(w)["barrier"];
            node(w)["entrance"];
          );
          out body;
        ''';
      } else {
        query =
            '''
          [out:json][timeout:10];
          (
            way($osmId);
            node(w)["barrier"];
            node(w)["entrance"];
          );
          out body;
        ''';
      }
    } else {
      query =
          '''
        [out:json][timeout:10];
        (
          node(around:$radius,$lat,$lon)["entrance"];
        );
        out body;
      ''';
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: {'data': query},
        headers: {'User-Agent': 'BkkTransitPlanner/1.0'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'] != null && data['elements'] is List) {
          final List<LatLng> entrances = [];
          for (var element in data['elements']) {
            if (element['lat'] != null && element['lon'] != null) {
              entrances.add(LatLng(element['lat'], element['lon']));
            }
          }

          // If a specific OSM-aware query (W/R) returned empty, do NOT fall back to a
          // radius-based search — that would pick up entrances from nearby unrelated
          // buildings (e.g. One Bangkok next to Lumphini Park). Return [] so the caller
          // can fall back to the centroid itself instead.

          return entrances;
        }
      } else {
        print('Overpass API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception calling Overpass API: $e');
    }

    // If the OSM-aware query fails/errors out, return [] — do NOT fall back to radius.
    // The caller will use the centroid as routing point, which is safer than a wrong
    // entrance from an adjacent building.

    return [];
  }
}
