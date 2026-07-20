import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bkk_transit_planner/providers/providers.dart';
import 'package:bkk_transit_planner/services/dijkstra_planner.dart';

/// Helper function to debug and print any route
void debugRoute(TransitGraph graph, String fromId, String toId, {List<String>? expectedManualPath}) {
  final offPeakTime = DateTime(2026, 1, 1, 12, 0); // Simulate off-peak time
  final result = graph.findShortestPath(fromId, toId, time: offPeakTime);
  expect(result, isNotNull, reason: 'No route found between $fromId and $toId');

  print('\n======================================================');
  print('ROUTE: $fromId -> $toId');
  print('======================================================');
  
  print('\n=== ACTUAL DIJKSTRA PATH ===');
  String prevLine = '';
  int transferCount = 0;
  for (final step in result!.path) {
    final s = graph.getStation(step.stationId);
    final isTransfer = step.lineId == 'TRANSFER';
    if (isTransfer) transferCount++;
    final lineChanged = step.lineId != prevLine && prevLine.isNotEmpty;
    if (lineChanged) print('  --- switch to ${step.lineId} ---');
    print('  ${s?.nameEn ?? step.stationId} (${step.stationId}) [${step.lineId}]${isTransfer ? " *** TRANSFER ***" : ""}');
    prevLine = step.lineId;
  }
  print('\nTotal transfers: $transferCount');
  print('Total time: ${result.totalWeight.toStringAsFixed(2)} min');

  if (expectedManualPath != null && expectedManualPath.isNotEmpty) {
    print('\n=== EXPECTED OPTIMAL PATH MANUAL CALC ===');
    double manual = 0;
    for (int i = 0; i < expectedManualPath.length - 1; i++) {
      final edges = graph.getEdges(expectedManualPath[i]);
      GraphEdge? e;
      for (final edge in edges) {
        if (edge.toId == expectedManualPath[i+1]) e = edge;
      }
      if (e != null) {
        double weight = e.weight;
        if (e.lineId == 'TRANSFER') weight += 5.0; // Off-peak transfer wait
        manual += weight;
        final s = graph.getStation(expectedManualPath[i+1]);
        print('  -> ${s?.nameEn ?? expectedManualPath[i+1]}: +${weight.toStringAsFixed(2)} min [${e.lineId}]');
      } else {
        print('  -> ${expectedManualPath[i+1]}: NO EDGE FOUND from ${expectedManualPath[i]} !!!');
      }
    }
    print('Expected path total: ${manual.toStringAsFixed(2)} min');
    print('Dijkstra savings vs expected: ${(manual - result.totalWeight).toStringAsFixed(2)} min');
  }
  print('\n');
}

void main() {
  test('Debug: Generic Routes Test Suite', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    final graph = repo.graph;

    // ---------------------------------------------------------
    // Scenario 1: ARL Lat Krabang -> MRT Lak Song
    // ---------------------------------------------------------
    debugRoute(
      graph,
      'ARL_A2',
      'MRT_BL38',
      expectedManualPath: [
        'ARL_A2','ARL_A3','ARL_A4','ARL_A5','ARL_A6',
        'MRT_BL21','MRT_BL22','MRT_BL23','MRT_BL24','MRT_BL25',
        'MRT_BL26','MRT_BL27','MRT_BL28','MRT_BL29','MRT_BL30',
        'MRT_BL31','MRT_BL32','MRT_BL01','MRT_BL33','MRT_BL34',
        'MRT_BL35','MRT_BL36','MRT_BL37','MRT_BL38'
      ],
    );

    // ---------------------------------------------------------
    // Add more scenarios below as needed:
    // debugRoute(graph, 'BTS_E1', 'MRT_BL22');
    // ---------------------------------------------------------
  });
}
