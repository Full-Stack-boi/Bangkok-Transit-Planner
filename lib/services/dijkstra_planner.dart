import 'dart:collection';
import '../models/station.dart';
import '../providers/disruption_provider.dart';
import '../core/constants/transit_constants.dart';

/// Edge in the transit graph
class GraphEdge {
  final String fromId;
  final String toId;
  final String lineId;
  final double weight; // travel time in minutes

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
  static final _whitespaceRegex = RegExp(r'\s+');

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
  void addEdge(
    String fromId,
    String toId,
    String lineId, {
    double weight = 2.0,
  }) {
    _adjacency.putIfAbsent(fromId, () => []);
    _adjacency.putIfAbsent(toId, () => []);

    _adjacency[fromId]!.add(
      GraphEdge(fromId: fromId, toId: toId, lineId: lineId, weight: weight),
    );
    _adjacency[toId]!.add(
      GraphEdge(fromId: toId, toId: fromId, lineId: lineId, weight: weight),
    );
  }

  /// Add a transfer edge between interchange stations (walking between platforms)
  void addTransferEdge(
    String fromId,
    String toId, {
    double walkingMinutes = 5.0,
  }) {
    _adjacency.putIfAbsent(fromId, () => []);
    _adjacency.putIfAbsent(toId, () => []);

    _adjacency[fromId]!.add(
      GraphEdge(
        fromId: fromId,
        toId: toId,
        lineId: 'TRANSFER',
        weight: walkingMinutes,
      ),
    );
    _adjacency[toId]!.add(
      GraphEdge(
        fromId: toId,
        toId: fromId,
        lineId: 'TRANSFER',
        weight: walkingMinutes,
      ),
    );
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
  DijkstraResult? findShortestPath(
    String fromId,
    String toId, {
    DateTime? time,
    DisruptionState? disruptionState,
  }) {
    if (!_stations.containsKey(fromId) || !_stations.containsKey(toId)) {
      return null;
    }
    if (fromId == toId) {
      return DijkstraResult(
        path: [PathStep(stationId: fromId, lineId: '', edgeWeight: 0)],
        totalWeight: 0,
      );
    }

    final dist = <String, double>{fromId: 0.0};
    final prev = <String, String?>{};
    final prevEdge = <String, GraphEdge?>{};
    final visited = <String>{};
    final pq = SplayTreeSet<_DijkstraNode>((a, b) {
      final cmp = a.distance.compareTo(b.distance);
      if (cmp != 0) return cmp;
      return a.stationId.compareTo(b.stationId);
    });

    final isPeak = TransitConstants.isPeakHour(time ?? DateTime.now());
    final transferWaitTime = isPeak ? 3.0 : 5.0;

    pq.add(_DijkstraNode(fromId, 0));

    while (pq.isNotEmpty) {
      final current = pq.first;
      pq.remove(current);

      if (current.stationId == toId) break;
      if (visited.contains(current.stationId)) continue;
      visited.add(current.stationId);

      for (final edge in getEdges(current.stationId)) {
        if (visited.contains(edge.toId)) continue;

        final currentDist = dist[current.stationId] ?? double.infinity;

        double actualWeight = edge.weight;
        if (edge.lineId == 'TRANSFER') {
          actualWeight += transferWaitTime;
        }

        double dijkstraCost = actualWeight;

        // Apply Disruption Penalties
        if (disruptionState != null && disruptionState.disruptions.isNotEmpty) {
          final isFromDisrupted = disruptionState.isStationDisrupted(
            current.stationId,
          );
          final isToDisrupted = disruptionState.isStationDisrupted(edge.toId);
          final isSegDisrupted = disruptionState.isSegmentDisrupted(
            current.stationId,
            edge.toId,
          );

          if (isFromDisrupted || isToDisrupted || isSegDisrupted) {
            final disruption =
                disruptionState.getDisruptionForStation(current.stationId) ??
                disruptionState.getDisruptionForStation(edge.toId);

            if (disruption != null) {
              if (disruption.isFullClosure || disruption.isPartialClosure) {
                dijkstraCost += 9999.0; // Force pathfinding to detour
              } else if (disruption.isMinorDelay) {
                final delay = (disruption.estimatedDelayMinutes ?? 10)
                    .toDouble();
                dijkstraCost += delay;
                actualWeight += delay;
              }
            } else if (isSegDisrupted) {
              dijkstraCost += 9999.0;
            }
          }
        }

        final newDist = currentDist + dijkstraCost;
        final edgeToDist = dist[edge.toId] ?? double.infinity;

        if (newDist < edgeToDist) {
          // Remove old entry if exists
          if (edgeToDist != double.infinity) {
            pq.remove(_DijkstraNode(edge.toId, edgeToDist));
          }
          dist[edge.toId] = newDist;
          prev[edge.toId] = current.stationId;
          prevEdge[edge.toId] = edge;
          pq.add(_DijkstraNode(edge.toId, newDist));
        }
      }
    }

    // Reconstruct path
    if (!dist.containsKey(toId)) return null;

    final path = <PathStep>[];
    String? current = toId;
    double totalPhysicalWeight = 0.0;

    while (current != null) {
      final edge = prevEdge[current];
      double stepWeight = edge?.weight ?? 0.0;

      if (edge != null) {
        if (edge.lineId == 'TRANSFER') {
          stepWeight += transferWaitTime;
        }
        if (disruptionState != null && disruptionState.disruptions.isNotEmpty) {
          final disruption =
              disruptionState.getDisruptionForStation(edge.fromId) ??
              disruptionState.getDisruptionForStation(edge.toId);
          if (disruption != null && disruption.isMinorDelay) {
            stepWeight += (disruption.estimatedDelayMinutes ?? 10).toDouble();
          }
        }
        totalPhysicalWeight += stepWeight;
      }

      path.add(
        PathStep(
          stationId: current,
          lineId: edge?.lineId ?? '',
          edgeWeight: stepWeight,
        ),
      );
      current = prev[current];
    }

    return DijkstraResult(
      path: path.reversed.toList(),
      totalWeight: totalPhysicalWeight,
    );
  }

  /// Search stations by name (Thai or English)
  List<Station> searchStations(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase().replaceAll(_whitespaceRegex, '');
    return _stations.values.where((s) {
      final normalizedTh = s.nameTh.toLowerCase().replaceAll(
        _whitespaceRegex,
        '',
      );
      final normalizedEn = s.nameEn.toLowerCase().replaceAll(
        _whitespaceRegex,
        '',
      );
      final normalizedCode = s.code.toLowerCase().replaceAll(
        _whitespaceRegex,
        '',
      );
      final normalizedId = s.id.toLowerCase().replaceAll(_whitespaceRegex, '');

      return normalizedTh.contains(q) ||
          normalizedEn.contains(q) ||
          normalizedCode.contains(q) ||
          normalizedId.contains(q);
    }).toList();
  }
}

/// A step in the Dijkstra path result
class PathStep {
  final String stationId;
  final String lineId; // Line used to reach this station ('' for origin)
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

  const DijkstraResult({required this.path, required this.totalWeight});

  /// Number of stations in the path
  int get stationCount => path.length;

  /// Get list of unique line IDs used (excluding TRANSFER)
  List<String> get lineIds => path
      .map((s) => s.lineId)
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
