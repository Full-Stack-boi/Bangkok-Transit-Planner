import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/services/fare_service.dart';
import 'package:bkk_transit_planner/features/search/route_calculator.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Route from Lat Krabang to MRT Phetchaburi includes transfer step', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();

    final fareService = FareService();
    final httpClient = http.Client();
    final routeCalculator = RouteCalculator(repo, fareService, httpClient);

    final origin = repo.getStation('ARL_A2'); // Lat Krabang
    final destination = repo.getStation('MRT_BL21'); // MRT Phetchaburi

    expect(origin, isNotNull);
    expect(destination, isNotNull);

    const cardState = CardStateSnapshot();
    const t = RouteTranslations(
      walkToStation: 'Walk to station',
      walkToDestination: 'Walk to destination',
      errorSamePlaces: 'Same place',
      errorNoRoute: 'No route',
      errorFailed: _failedMsg,
    );

    final result = routeCalculator.calculate(
      origin!,
      destination!,
      cardState,
      t,
    );

    expect(result, isNotNull);
    final recommended = result!.recommended;

    print('\n=== ROUTE SEGMENTS ===');
    for (final seg in recommended.segments) {
      print(
        'Segment: ${seg.fromStation.nameEn} -> ${seg.toStation.nameEn} [${seg.lineId}]',
      );
    }

    print('\n=== TRANSFERS ===');
    for (final tr in recommended.transfers) {
      print(
        'Transfer: ${tr.fromStation.nameEn} (${tr.fromStation.id}) -> ${tr.toStation.nameEn} (${tr.toStation.id})',
      );
    }

    // 1. Should have ARL transit segment from Lat Krabang to Makkasan
    expect(recommended.segments.isNotEmpty, isTrue);
    expect(recommended.segments.first.fromStation.id, equals('ARL_A2'));
    expect(
      recommended.segments.first.toStation.id,
      equals('ARL_A6'),
    ); // Makkasan

    // 2. Should have a TransferStep from ARL Makkasan (ARL_A6) to MRT Phetchaburi (MRT_BL21)
    expect(recommended.transfers.isNotEmpty, isTrue);
    final transfer = recommended.transfers.first;
    expect(transfer.fromStation.id, equals('ARL_A6'));
    expect(transfer.toStation.id, equals('MRT_BL21'));
  });
}

String _failedMsg(String err) => 'Failed: $err';
