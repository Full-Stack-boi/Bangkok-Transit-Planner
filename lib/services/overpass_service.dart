import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OverpassService {
  // Use Vercel Serverless Function proxy on Web to bypass CORS and avoid 404s.
  // For other platforms (Android/iOS), use the direct LZ4 mirror URL.
  final String _baseUrl = kIsWeb
      ? '/api/overpass'
      : 'https://lz4.overpass-api.de/api/interpreter';

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
          [out:json][timeout:5];
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
          [out:json][timeout:5];
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
        [out:json][timeout:5];
        (
          node(around:$radius,$lat,$lon)["entrance"];
        );
        out body;
      ''';
    }

    int attempts = 2;
    int timeoutSeconds = 7;

    for (int i = 0; i < attempts; i++) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          body: {'data': query},
          headers: {
            'User-Agent': 'BkkTransitPlanner/1.0',
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ).timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['elements'] != null && data['elements'] is List) {
            final List<LatLng> entrances = [];
            for (var element in data['elements']) {
              if (element['lat'] != null && element['lon'] != null) {
                entrances.add(LatLng(element['lat'], element['lon']));
              }
            }
            return entrances;
          }
        } else {
          print('Overpass API error on attempt ${i + 1}: ${response.statusCode}');
        }
      } catch (e) {
        print('Exception calling Overpass API on attempt ${i + 1}: $e');
        if (i == attempts - 1) {
          rethrow; // Rethrow on last attempt so caller knows it failed
        }
      }
    }

    // If the OSM-aware query fails/errors out, return [] — do NOT fall back to radius.
    // The caller will use the centroid as routing point, which is safer than a wrong
    // entrance from an adjacent building.

    return [];
  }
}
