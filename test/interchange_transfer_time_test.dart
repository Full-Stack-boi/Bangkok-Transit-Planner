import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/core/constants/transit_constants.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';

void main() {
  group('Station-Specific Interchange Transfer Walk Times', () {
    test('TransitConstants.getInterchangeWalkMinutes returns correct walk time', () {
      // Cross-platform: Siam
      expect(
        TransitConstants.getInterchangeWalkMinutes('BTS_CEN', 'BTS_CEN_SILOM'),
        equals(1.0),
      );
      // Order independence
      expect(
        TransitConstants.getInterchangeWalkMinutes('BTS_CEN_SILOM', 'BTS_CEN'),
        equals(1.0),
      );

      // Skywalk: Asok / Sukhumvit
      expect(
        TransitConstants.getInterchangeWalkMinutes('BTS_E4', 'MRT_BL22'),
        equals(5.0),
      );
      expect(
        TransitConstants.getInterchangeWalkMinutes('MRT_BL22', 'BTS_E4'),
        equals(5.0),
      );

      // Grand station walk: Bang Sue / Krung Thep Aphiwat
      expect(
        TransitConstants.getInterchangeWalkMinutes('MRT_BL11', 'SRT_RN00'),
        equals(6.0),
      );

      // Mo Chit / Chatuchak Park
      expect(
        TransitConstants.getInterchangeWalkMinutes('BTS_N8', 'MRT_BL13'),
        equals(4.0),
      );

      // Unknown pair returns null (fallback to formula)
      expect(
        TransitConstants.getInterchangeWalkMinutes('BTS_N1', 'BTS_N2'),
        isNull,
      );
    });

    test('TransitRepository graph builds transfer edges with specific walk times', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final repo = TransitRepository();
      await repo.initialize();

      final graph = repo.graph;

      // Check Siam transfer edge weight
      final siamEdges = graph.getEdges('BTS_CEN');
      final siamTransferEdge = siamEdges.firstWhere(
        (e) => e.toId == 'BTS_CEN_SILOM' && e.lineId == 'TRANSFER',
      );
      expect(siamTransferEdge.weight, equals(1.0));

      // Check Asok / Sukhumvit transfer edge weight
      final asokEdges = graph.getEdges('BTS_E4');
      final asokTransferEdge = asokEdges.firstWhere(
        (e) => e.toId == 'MRT_BL22' && e.lineId == 'TRANSFER',
      );
      expect(asokTransferEdge.weight, equals(5.0));

      // Check Bang Sue transfer edge weight
      final bangSueEdges = graph.getEdges('MRT_BL11');
      final bangSueTransferEdge = bangSueEdges.firstWhere(
        (e) => e.toId == 'SRT_RN00' && e.lineId == 'TRANSFER',
      );
      expect(bangSueTransferEdge.weight, equals(6.0));
    });
  });
}
