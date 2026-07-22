import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/models/transit_disruption.dart';
import 'package:bkk_transit_planner/providers/disruption_provider.dart';
import 'package:bkk_transit_planner/services/dijkstra_planner.dart';

void main() {
  group('Disruption Pathfinding Integration Tests', () {
    late TransitGraph graph;

    setUp(() {
      graph = TransitGraph();
      // Setup simple line A: S1 -> S2 -> S3 (Line A)
      graph.addStation(
        const Station(
          id: 'S1',
          code: 'S1',
          nameTh: 'สถานี 1',
          nameEn: 'Station 1',
          lineId: 'LINE_A',
          lat: 13.7,
          lng: 100.5,
        ),
      );
      graph.addStation(
        const Station(
          id: 'S2',
          code: 'S2',
          nameTh: 'สถานี 2',
          nameEn: 'Station 2',
          lineId: 'LINE_A',
          lat: 13.71,
          lng: 100.51,
        ),
      );
      graph.addStation(
        const Station(
          id: 'S3',
          code: 'S3',
          nameTh: 'สถานี 3',
          nameEn: 'Station 3',
          lineId: 'LINE_A',
          lat: 13.72,
          lng: 100.52,
        ),
      );

      // Add edges for Line A (2 mins each)
      graph.addEdge('S1', 'S2', 'LINE_A', weight: 2.0);
      graph.addEdge('S2', 'S3', 'LINE_A', weight: 2.0);

      // Add parallel Line B: S1 -> B2 -> S3 (Line B) as bypass
      graph.addStation(
        const Station(
          id: 'B2',
          code: 'B2',
          nameTh: 'ทางเลี่ยง B2',
          nameEn: 'Bypass B2',
          lineId: 'LINE_B',
          lat: 13.715,
          lng: 100.515,
        ),
      );
      graph.addTransferEdge('S1', 'B2', walkingMinutes: 3.0);
      graph.addTransferEdge('B2', 'S3', walkingMinutes: 3.0);
    });

    test('Normal state uses shortest direct route S1 -> S2 -> S3', () {
      final res = graph.findShortestPath('S1', 'S3');
      expect(res, isNotNull);
      expect(res!.path.map((p) => p.stationId).toList(), ['S1', 'S2', 'S3']);
      expect(res.totalWeight, closeTo(4.0, 0.1));
    });

    test('Disrupted middle station S2 forces detour via Line B (B2)', () {
      final disruptionState = DisruptionState(
        isMockActive: true,
        disruptions: [
          TransitDisruption(
            id: 'mock_s2_closed',
            lineId: 'LINE_A',
            severity: DisruptionSeverity.partialClosure,
            affectedStationIds: ['S2'],
            affectedSegmentIds: ['S1->S2', 'S2->S3'],
            titleTh: 'S2 ปิดให้บริการ',
            titleEn: 'S2 Closed',
            descriptionTh: 'ปิดสถานี S2',
            descriptionEn: 'Station S2 closed',
            reportedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final res = graph.findShortestPath(
        'S1',
        'S3',
        disruptionState: disruptionState,
      );
      expect(res, isNotNull);
      // Path must avoid S2 and use B2 bypass!
      expect(res!.path.map((p) => p.stationId).toList(), contains('B2'));
      expect(res.path.map((p) => p.stationId).toList(), isNot(contains('S2')));
    });

    test('Minor delay at S2 adds delay penalty without breaking path', () {
      final disruptionState = DisruptionState(
        isMockActive: true,
        disruptions: [
          TransitDisruption(
            id: 'mock_s2_delay',
            lineId: 'LINE_A',
            severity: DisruptionSeverity.minorDelay,
            affectedStationIds: ['S2'],
            affectedSegmentIds: [],
            titleTh: 'S2 ล่าช้า',
            titleEn: 'S2 Delayed',
            descriptionTh: 'ล่าช้า 15 นาที',
            descriptionEn: '15 mins delay',
            estimatedDelayMinutes: 15,
            reportedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final res = graph.findShortestPath(
        'S1',
        'S3',
        disruptionState: disruptionState,
      );
      expect(res, isNotNull);
      // Extra 15 mins makes direct route 19 mins vs bypass route 16 mins (3+5+3+5), so bypass is preferred!
      expect(res!.path.map((p) => p.stationId).toList(), contains('B2'));
    });
  });
}
