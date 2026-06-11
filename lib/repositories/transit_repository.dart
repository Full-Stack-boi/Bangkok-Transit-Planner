import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../models/line.dart';
import '../models/landmark.dart';
import '../models/custom_location.dart';
import '../models/searchable_item.dart';
import '../services/dijkstra_planner.dart';

/// Repository for loading and accessing static transit data
class TransitRepository {
  List<Station>? _stations;
  List<TransitLine>? _lines;
  List<Landmark>? _landmarks;
  TransitGraph? _graph;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<Station> get stations => _stations ?? [];
  List<TransitLine> get lines => _lines ?? [];
  List<Landmark> get landmarks => _landmarks ?? [];
  TransitGraph get graph => _graph!;

  /// Initialize repository by loading all static data
  Future<void> initialize() async {
    if (_initialized) return;

    await Future.wait([
      _loadStations(),
      _loadLines(),
      _loadLandmarks(),
    ]);

    _buildGraph();
    _initialized = true;
  }

  Future<void> _loadStations() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/stations.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _stations = jsonList.map((j) => Station.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      // If JSON not available yet, use empty list
      _stations = [];
    }
  }

  Future<void> _loadLines() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/lines.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _lines = jsonList.map((j) => TransitLine.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _lines = [];
    }
  }

  Future<void> _loadLandmarks() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/landmarks.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _landmarks = jsonList.map((j) => Landmark.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _landmarks = [];
    }
  }

  void _buildGraph() {
    _graph = TransitGraph();

    // Add all stations to graph
    for (final station in _stations!) {
      _graph!.addStation(station);
    }

    // Add edges between consecutive stations on each line
    for (final line in _lines!) {
      for (int i = 0; i < line.stationIds.length - 1; i++) {
        _graph!.addEdge(
          line.stationIds[i],
          line.stationIds[i + 1],
          line.id,
          weight: 2.0, // ~2 min between stations
        );
      }

      // For loop lines (MRT Blue), connect last to first
      if (line.isLoop && line.stationIds.length > 2) {
        _graph!.addEdge(
          line.stationIds.last,
          line.stationIds.first,
          line.id,
          weight: 2.0,
        );
      }
    }

    // Add transfer edges for interchange stations
    for (final station in _stations!) {
      for (final interchangeId in station.interchange) {
        final target = getStation(interchangeId);
        double walkMin = 5.0;
        if (target != null && target.nameEn == station.nameEn) {
          if (station.id.startsWith('BTS_CEN') ||
              station.id.startsWith('MRT_BL01') ||
              station.id.startsWith('MRT_BL33')) {
            walkMin = 1.0; // Same station platform transfer (Siam or Tha Phra)
          } else {
            walkMin = 2.0; // Same-name adjacent station connection (e.g. Phaya Thai BTS/ARL, Lat Phrao Blue/Yellow)
          }
        }
        _graph!.addTransferEdge(
          station.id,
          interchangeId,
          walkingMinutes: walkMin,
        );
      }
    }
  }

  /// Search stations by query (Thai/English name or code)
  List<Station> searchStations(String query) {
    if (_graph == null) return [];
    return _graph!.searchStations(query);
  }

  /// Get a station by ID
  Station? getStation(String id) {
    return _graph?.getStation(id);
  }

  /// Get a line by ID
  TransitLine? getLine(String lineId) {
    return _lines?.firstWhere(
      (l) => l.id == lineId,
      orElse: () => throw StateError('Line not found: $lineId'),
    );
  }

  /// Get all stations on a line
  List<Station> getStationsOnLine(String lineId) {
    final line = getLine(lineId);
    if (line == null) return [];
    return line.stationIds
        .map((id) => getStation(id))
        .whereType<Station>()
        .toList();
  }

  /// Find shortest path between two stations
  DijkstraResult? findRoute(String fromId, String toId) {
    return _graph?.findShortestPath(fromId, toId);
  }

  /// Search stations and local landmarks by query
  List<SearchableItem> searchLocalPlaces(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();

    final matchingStations = searchStations(query);

    final matchingLandmarks = (_landmarks ?? []).where((l) {
      return l.nameTh.toLowerCase().contains(q) ||
             l.nameEn.toLowerCase().contains(q);
    }).toList();

    return [...matchingStations, ...matchingLandmarks];
  }

  /// Search places online via OpenStreetMap Nominatim API, bounded to Bangkok
  Future<List<CustomLocation>> searchOnlinePlaces(String query) async {
    if (query.trim().length < 3) return [];

    final client = HttpClient();
    client.userAgent = 'com.bkktransit.bkk_transit_planner'; // Required by Nominatim Policy

    try {
      // Bounded search within Bangkok area (viewbox=99.0,13.0,101.5,14.5&bounded=1)
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=th&viewbox=99.0,13.0,101.5,14.5&bounded=1'
      );

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> jsonList = json.decode(body);

        final results = <CustomLocation>[];

        for (final item in jsonList) {
          final lat = double.tryParse(item['lat'] as String) ?? 0.0;
          final lon = double.tryParse(item['lon'] as String) ?? 0.0;
          if (lat == 0.0 || lon == 0.0) continue;

          final displayName = item['display_name'] as String;
          // Extract shorter display name
          final parts = displayName.split(',');
          final shortName = parts.isNotEmpty ? parts.first.trim() : displayName;

          // Find nearest station
          final nearest = _findNearestStation(lat, lon);
          if (nearest != null) {
            final dist = Geolocator.distanceBetween(lat, lon, nearest.lat, nearest.lng);
            // Walking minutes based on 80 meters/minute, capped between 1 and 30 mins
            final walkMin = (dist / 80.0).clamp(1.0, 30.0);

            results.add(CustomLocation(
              id: 'OSM_${item['place_id'] ?? DateTime.now().millisecondsSinceEpoch}',
              nameTh: shortName,
              nameEn: shortName,
              nearestStationId: nearest.id,
              walkingMinutes: walkMin,
              lat: lat,
              lng: lon,
            ));
          }
        }
        return results;
      }
    } catch (e) {
      print('Online place search failed: $e');
    } finally {
      client.close();
    }
    return [];
  }

  Station? _findNearestStation(double lat, double lon) {
    if (_stations == null || _stations!.isEmpty) return null;

    Station? closest;
    double minDist = double.infinity;

    for (final station in _stations!) {
      final dist = Geolocator.distanceBetween(lat, lon, station.lat, station.lng);
      if (dist < minDist) {
        minDist = dist;
        closest = station;
      }
    }
    return closest;
  }
}
