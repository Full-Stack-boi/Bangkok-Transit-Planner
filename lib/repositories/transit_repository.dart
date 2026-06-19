import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../models/line.dart';
import '../models/landmark.dart';
import '../models/custom_location.dart';
import '../models/searchable_item.dart';
import '../models/station_exit.dart';
import '../services/dijkstra_planner.dart';

/// Repository for loading and accessing static transit data
class TransitRepository {
  List<Station>? _stations;
  List<TransitLine>? _lines;
  List<Landmark>? _landmarks;
  List<StationExit> _exits = [];
  TransitGraph? _graph;
  bool _initialized = false;

  final Map<String, Station> _stationCache = {};
  final Map<String, TransitLine> _lineCache = {};
  final Map<String, List<Station>> _lineStationsCache = {};

  bool get isInitialized => _initialized;
  List<Station> get stations => _stations ?? [];
  List<TransitLine> get lines => _lines ?? [];
  List<Landmark> get landmarks => _landmarks ?? [];
  List<StationExit> get exits => _exits;
  TransitGraph get graph => _graph!;

  /// Initialize repository by loading all static data
  Future<void> initialize() async {
    if (_initialized) return;

    await Future.wait([
      _loadStations(),
      _loadLines(),
      _loadLandmarks(),
      _loadExits(),
    ]);

    _buildGraph();
    _initialized = true;
  }

  Future<void> _loadExits() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/station_exits.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _exits = jsonList.map((j) => StationExit.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _exits = [];
      print('Failed to load station exits: $e');
    }
  }

  List<StationExit> getExitsForStation(String stationId) {
    return _exits.where((e) => e.stationId == stationId).toList();
  }

  Future<void> _loadStations() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/stations.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _stations = jsonList.map((j) => Station.fromJson(j as Map<String, dynamic>)).toList();
      _stationCache.clear();
      for (final s in _stations!) {
        _stationCache[s.id] = s;
      }
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
      _lineCache.clear();
      for (final l in _lines!) {
        _lineCache[l.id] = l;
      }
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
    return _stationCache[id] ?? _graph?.getStation(id);
  }

  /// Get a line by ID
  TransitLine? getLine(String lineId) {
    if (_lineCache.containsKey(lineId)) return _lineCache[lineId];
    return _lines?.firstWhere(
      (l) => l.id == lineId,
      orElse: () => throw StateError('Line not found: $lineId'),
    );
  }

  /// Get all stations on a line
  List<Station> getStationsOnLine(String lineId) {
    if (_lineStationsCache.containsKey(lineId)) {
      return _lineStationsCache[lineId]!;
    }
    final line = getLine(lineId);
    if (line == null) return [];
    final list = line.stationIds
        .map((id) => getStation(id))
        .whereType<Station>()
        .toList();
    _lineStationsCache[lineId] = list;
    return list;
  }

  /// Find shortest path between two stations
  DijkstraResult? findRoute(String fromId, String toId) {
    return _graph?.findShortestPath(fromId, toId);
  }

  /// Search stations and local landmarks by query
  List<SearchableItem> searchLocalPlaces(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    final matchingStations = searchStations(query);

    final matchingLandmarks = (_landmarks ?? []).where((l) {
      final normalizedTh = l.nameTh.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final normalizedEn = l.nameEn.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return normalizedTh.contains(q) ||
             normalizedEn.contains(q);
    }).toList();

    return [...matchingStations, ...matchingLandmarks];
  }

  /// Search places online via Photon API (Elasticsearch-based autocomplete), bounded to Bangkok
  Future<List<CustomLocation>> searchOnlinePlaces(String query) async {
    if (query.trim().length < 3) return [];

    final client = HttpClient();
    client.userAgent = 'com.bkktransit.bkk_transit_planner';

    try {
      // Query Photon API with Bangkok location bias (lat=13.7563, lon=100.5018)
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5&lat=13.7563&lon=100.5018&lang=en'
      );

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(body);
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
          final nearest = _findNearestStation(lat, lon);
          if (nearest != null) {
            final dist = Geolocator.distanceBetween(lat, lon, nearest.lat, nearest.lng);
            // Limit results to locations within 12 km of a transit station to filter out far-away provinces
            if (dist <= 12000.0) {
              // Walking minutes based on 80 meters/minute, capped between 1 and 30 mins
              final walkMin = (dist / 80.0).clamp(1.0, 30.0);

              results.add(CustomLocation(
                id: 'OSM_${properties['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}',
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
