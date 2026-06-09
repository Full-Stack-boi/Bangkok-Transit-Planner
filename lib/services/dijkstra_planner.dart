import 'dart:collection';
import '../models/station.dart';

/// Edge in the transit graph
class GraphEdge {
  final String fromId;
  final String toId;
  final String lineId;
  final double weight;  // travel time in minutes

  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.lineId,
    required this.weight,
  });
}

/// Node with distance for Dijkstra priority queue
class _DijkstraNode implements Comparable<_DijkstraNode> {
  final String stationId;
  final double distance;

  const _DijkstraNode(this.stationId, this.distance);

  @override
  int compareTo(_DijkstraNode other) => distance.compareTo(other.distance);
}

/// Transit graph for all Bangkok rail stations
class TransitGraph {
  final Map<String, Station> _stations = {};
  final Map<String, List<GraphEdge>> _adjacency = {};

  /// All stations in the graph
  Map<String, Station> get stations => Map.unmodifiable(_stations);

  /// Add a station to the graph
  void addStation(Station station) {
    _stations[station.id] = station;
    _adjacency.putIfAbsent(station.id, () => []);
  }

  /// Add a bidirectional edge (same-line connection)
  void addEdge(String fromId, String toId, String lineId, {double weight = 2.0}) {
    _adjacency.putIfAbsent(fromId, () => []);
    _adjacency.putIfAbsent(toId, () => []);

    _adjacency[fromId]!.add(GraphEdge(
      fromId: fromId,
      toId: toId,
      lineId: lineId,
      weight: weight,
    ));
    _adjacency[toId]!.add(GraphEdge(
      fromId: toId,
      toId: fromId,
      lineId: lineId,
      weight: weight,
    ));
  }

  /// Add a transfer edge between interchange stations (walking between platforms)
  void addTransferEdge(String fromId, String toId, {double walkingMinutes = 5.0}) {
    _adjacency.putIfAbsent(fromId, () => []);
    _adjacency.putIfAbsent(toId, () => []);

    _adjacency[fromId]!.add(GraphEdge(
      fromId: fromId,
      toId: toId,
      lineId: 'TRANSFER',
      weight: walkingMinutes,
    ));
    _adjacency[toId]!.add(GraphEdge(
      fromId: toId,
      toId: fromId,
      lineId: 'TRANSFER',
      weight: walkingMinutes,
    ));
  }

  /// Get all edges from a station
  List<GraphEdge> getEdges(String stationId) {
    return _adjacency[stationId] ?? [];
  }

  /// Get a station by ID
  Station? getStation(String stationId) {
    return _stations[stationId];
  }

  /// Find shortest path using Dijkstra's algorithm
  /// Returns list of (stationId, lineId) pairs representing the path
  DijkstraResult? findShortestPath(String fromId, String toId) {
    if (!_stations.containsKey(fromId) || !_stations.containsKey(toId)) {
      return null;
    }
    if (fromId == toId) {
      return DijkstraResult(
        path: [PathStep(stationId: fromId, lineId: '', edgeWeight: 0)],
        totalWeight: 0,
      );
    }

    final dist = <String, double>{};
    final prev = <String, String?>{};
    final prevEdge = <String, GraphEdge?>{};
    final visited = <String>{};
    final pq = SplayTreeSet<_DijkstraNode>((a, b) {
      final cmp = a.distance.compareTo(b.distance);
      if (cmp != 0) return cmp;
      return a.stationId.compareTo(b.stationId);
    });

    for (final id in _stations.keys) {
      dist[id] = double.infinity;
      prev[id] = null;
      prevEdge[id] = null;
    }
    dist[fromId] = 0;
    pq.add(_DijkstraNode(fromId, 0));

    while (pq.isNotEmpty) {
      final current = pq.first;
      pq.remove(current);

      if (current.stationId == toId) break;
      if (visited.contains(current.stationId)) continue;
      visited.add(current.stationId);

      for (final edge in getEdges(current.stationId)) {
        if (visited.contains(edge.toId)) continue;

        // Add a small penalty for transfers to prefer direct routes
        double penalty = 0;
        if (prevEdge[current.stationId] != null &&
            prevEdge[current.stationId]!.lineId != edge.lineId &&
            edge.lineId != 'TRANSFER' &&
            prevEdge[current.stationId]!.lineId != 'TRANSFER') {
          penalty = 3.0; // 3 min penalty for unnecessary line changes
        }

        final newDist = dist[current.stationId]! + edge.weight + penalty;
        if (newDist < dist[edge.toId]!) {
          // Remove old entry if exists
          pq.remove(_DijkstraNode(edge.toId, dist[edge.toId]!));
          dist[edge.toId] = newDist;
          prev[edge.toId] = current.stationId;
          prevEdge[edge.toId] = edge;
          pq.add(_DijkstraNode(edge.toId, newDist));
        }
      }
    }

    // Reconstruct path
    if (dist[toId] == double.infinity) return null;

    final path = <PathStep>[];
    String? current = toId;
    while (current != null) {
      final edge = prevEdge[current];
      path.add(PathStep(
        stationId: current,
        lineId: edge?.lineId ?? '',
        edgeWeight: edge?.weight ?? 0,
      ));
      current = prev[current];
    }
    path.reversed;

    return DijkstraResult(
      path: path.reversed.toList(),
      totalWeight: dist[toId]!,
    );
  }

  /// Search stations by name (Thai or English)
  List<Station> searchStations(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _stations.values.where((s) {
      return s.nameTh.toLowerCase().contains(q) ||
             s.nameEn.toLowerCase().contains(q) ||
             s.code.toLowerCase().contains(q) ||
             s.id.toLowerCase().contains(q);
    }).toList();
  }
}

/// A step in the Dijkstra path result
class PathStep {
  final String stationId;
  final String lineId;   // Line used to reach this station ('' for origin)
  final double edgeWeight;

  const PathStep({
    required this.stationId,
    required this.lineId,
    required this.edgeWeight,
  });
}

/// Result of Dijkstra shortest path
class DijkstraResult {
  final List<PathStep> path;
  final double totalWeight;

  const DijkstraResult({
    required this.path,
    required this.totalWeight,
  });

  /// Number of stations in the path
  int get stationCount => path.length;

  /// Get list of unique line IDs used (excluding TRANSFER)
  List<String> get lineIds =>
      path.map((s) => s.lineId)
          .where((id) => id.isNotEmpty && id != 'TRANSFER')
          .toSet()
          .toList();

  /// Number of transfers
  int get transferCount {
    int count = 0;
    for (int i = 1; i < path.length; i++) {
      if (path[i].lineId == 'TRANSFER') count++;
    }
    return count;
  }
}
