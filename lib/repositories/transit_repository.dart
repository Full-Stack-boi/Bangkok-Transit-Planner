import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/station.dart';
import '../models/line.dart';
import '../services/dijkstra_planner.dart';

/// Repository for loading and accessing static transit data
class TransitRepository {
  List<Station>? _stations;
  List<TransitLine>? _lines;
  TransitGraph? _graph;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<Station> get stations => _stations ?? [];
  List<TransitLine> get lines => _lines ?? [];
  TransitGraph get graph => _graph!;

  /// Initialize repository by loading all static data
  Future<void> initialize() async {
    if (_initialized) return;

    await Future.wait([
      _loadStations(),
      _loadLines(),
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
}
