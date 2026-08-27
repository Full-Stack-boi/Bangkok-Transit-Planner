import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/models/transit_enums.dart';
import 'package:bkk_transit_planner/services/fare_service.dart';

void main() {
  group('FareService Tests', () {
    late FareService fareService;

    setUp(() {
      fareService = FareService();
    });

    test('MRT Yellow Line should charge 27 THB for 3 stations (e.g. Hua Mak -> Bang Kapi)', () {
      expect(fareService.calculateFare('MRT_YELLOW', 0), equals(15));
      expect(fareService.calculateFare('MRT_YELLOW', 1), equals(19));
      expect(fareService.calculateFare('MRT_YELLOW', 2), equals(23));
      expect(fareService.calculateFare('MRT_YELLOW', 3), equals(27));
      expect(fareService.calculateFare('MRT_YELLOW', 4), equals(30));
      expect(fareService.calculateFare('MRT_YELLOW', 5), equals(33));
      expect(fareService.calculateFare('MRT_YELLOW', 9), equals(45));
    });

    test('MRT Pink Line should follow 15-45 THB distance step', () {
      expect(fareService.calculateFare('MRT_PINK', 0), equals(15));
      expect(fareService.calculateFare('MRT_PINK', 1), equals(19));
      expect(fareService.calculateFare('MRT_PINK', 2), equals(23));
      expect(fareService.calculateFare('MRT_PINK', 3), equals(27));
      expect(fareService.calculateFare('MRT_PINK', 9), equals(45));
    });

    test('MRT Blue Line should charge 17-44 THB', () {
      expect(fareService.calculateFare('MRT_BLUE', 0), equals(17));
      expect(fareService.calculateFare('MRT_BLUE', 1), equals(17));
      expect(fareService.calculateFare('MRT_BLUE', 2), equals(20));
      expect(fareService.calculateFare('MRT_BLUE', 3), equals(22));
      expect(fareService.calculateFare('MRT_BLUE', 12), equals(44));
    });

    test('BTS Gold Line should have 16 THB flat fare', () {
      expect(fareService.calculateFare('BTS_GOLD', 0), equals(16));
      expect(fareService.calculateFare('BTS_GOLD', 1), equals(16));
      expect(fareService.calculateFare('BTS_GOLD', 2), equals(16));
    });

    test('Rabbit card discounts apply to Yellow Line and MRT card discounts apply to Blue Line', () {
      // Yellow Line: 27 THB standard for 3 stations
      // MRT Card (BEM) should NOT affect Yellow Line
      expect(fareService.calculateFare('MRT_YELLOW', 3, mrtCardType: TransitCardType.senior), equals(27));
      expect(fareService.calculateFare('MRT_YELLOW', 3, mrtCardType: TransitCardType.student), equals(27));

      // Rabbit Card (BTS/EBM/NBM) SHOULD discount Yellow Line
      expect(fareService.calculateFare('MRT_YELLOW', 3, btsCardType: TransitCardType.senior), equals(14)); // 50% of 27 = 13.5 -> 14
      expect(fareService.calculateFare('MRT_YELLOW', 3, btsCardType: TransitCardType.student), equals(24)); // 90% of 27 = 24.3 -> 24

      // MRT Card SHOULD discount Blue Line
      expect(fareService.calculateFare('MRT_BLUE', 2, mrtCardType: TransitCardType.senior), equals(10)); // 50% of 20 = 10
      expect(fareService.calculateFare('MRT_BLUE', 2, mrtCardType: TransitCardType.student), equals(18)); // 90% of 20 = 18
    });

    test('calculateTotalFare waives entry fee for valid interchange pairs only', () {
      // 1. MRT Blue (2 stations = 20 THB) -> MRT Yellow (2 stations = 23 THB, entry fee = 15 THB)
      // Lat Phrao qualifying pair: 20 + 23 - 15 = 28 THB
      final blueToYellow = [
        const FareSegment(lineId: 'MRT_BLUE', stationCount: 2),
        const FareSegment(lineId: 'MRT_YELLOW', stationCount: 2),
      ];
      expect(fareService.calculateTotalFare(blueToYellow), equals(28));

      // 2. Yellow -> Pink (No direct interchange, does NOT qualify for transfer waiver)
      // Yellow (2 stations = 23 THB) + Pink (2 stations = 23 THB) = 46 THB
      final yellowToPink = [
        const FareSegment(lineId: 'MRT_YELLOW', stationCount: 2),
        const FareSegment(lineId: 'MRT_PINK', stationCount: 2),
      ];
      expect(fareService.calculateTotalFare(yellowToPink), equals(46));
    });
  });
}
