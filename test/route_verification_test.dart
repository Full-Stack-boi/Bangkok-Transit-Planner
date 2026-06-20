import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bkk_transit_planner/providers/providers.dart';
import 'package:bkk_transit_planner/models/landmark.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/features/search/search_view_model.dart';

void main() {
  test('Verify Route Calculation and Walking Instructions between Siam and MBK', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize container with real repository
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    
    // 1. Find Siam Station (BTS_CEN) and MBK Center (LM_MBK)
    final siamStation = repo.getStation('BTS_CEN') as Station?;
    final mbkLandmark = repo.landmarks.firstWhere((l) => l.id == 'LM_MBK');
    
    expect(siamStation, isNotNull);
    expect(mbkLandmark, isNotNull);
    
    final searchVm = container.read(searchViewModelProvider.notifier);
    
    // 2. Route from Siam Station to MBK Center
    await searchVm.setOrigin(siamStation!);
    await searchVm.setDestination(mbkLandmark);
    
    final state = container.read(searchViewModelProvider);
    expect(state.error, isNull);
    expect(state.routeResult, isNotNull);
    
    final result = state.routeResult!;
    print('======================================');
    print('RECOMMENDED ROUTE: Siam Station (BTS_CEN) -> MBK Center');
    print('======================================');
    print('Total Minutes: ${result.totalMinutes}');
    print('Segment Count: ${result.segments.length}');
    for (int i = 0; i < result.segments.length; i++) {
      final s = result.segments[i];
      print('  Segment $i: ${s.lineId} (${s.lineName}) from ${s.fromStation.id} to ${s.toStation.id}');
      print('    Exit: ${s.exit?.exitCode}, Path points: ${s.walkingPath?.length}');
    }

    final saverRoute = state.saverRoute;
    expect(saverRoute, isNotNull);
    
    print('======================================');
    print('SAVER ROUTE: Siam Station (BTS_CEN) -> MBK Center');
    print('======================================');
    print('Total Minutes: ${saverRoute!.totalMinutes}');
    print('Segment Count: ${saverRoute.segments.length}');
    for (int i = 0; i < saverRoute.segments.length; i++) {
      final s = saverRoute.segments[i];
      print('  Segment $i: ${s.lineId} (${s.lineName}) from ${s.fromStation.id} to ${s.toStation.id}');
      print('    Exit: ${s.exit?.exitCode}, Path points: ${s.walkingPath?.length}');
    }

    // The saver route should be a single direct WALK segment
    expect(saverRoute.segments.length, equals(1));
    final segment = saverRoute.segments.first;
    expect(segment.lineId, equals('WALK'));
    expect(segment.exit?.exitCode, equals('1'));
    print('Exit code used at Siam (Saver): ${segment.exit?.exitCode}');

    // Verify coordinates match our Siam -> MBK True Skywalk (5 points)
    expect(segment.walkingPath, isNotNull);
    print('Walking Path Coordinates Count: ${segment.walkingPath!.length}');
    for (int i = 0; i < segment.walkingPath!.length; i++) {
      print('  Point $i: ${segment.walkingPath![i].latitude}, ${segment.walkingPath![i].longitude}');
    }
    expect(segment.walkingPath!.length, equals(5));

    // Verify localized instructions
    print('Instructions (TH): ${segment.instructionsTh}');
    print('Instructions (EN): ${segment.instructionsEn}');
    expect(segment.instructionsTh, contains('Siam Center'));
    expect(segment.instructionsEn, contains('indoor skywalk'));
    print('======================================');
  });

  test('Verify Route Calculation and Walking Instructions between National Stadium and MBK', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    
    final w1Station = repo.getStation('BTS_W1') as Station?;
    final mbkLandmark = repo.landmarks.firstWhere((l) => l.id == 'LM_MBK');
    
    expect(w1Station, isNotNull);
    expect(mbkLandmark, isNotNull);
    
    final searchVm = container.read(searchViewModelProvider.notifier);
    
    await searchVm.setOrigin(w1Station!);
    await searchVm.setDestination(mbkLandmark);
    
    final state = container.read(searchViewModelProvider);
    expect(state.error, isNull);
    expect(state.routeResult, isNotNull);
    
    final result = state.routeResult!;
    print('======================================');
    print('ROUTE: National Stadium (BTS_W1) -> MBK Center');
    print('======================================');
    print('Total Minutes: ${result.totalMinutes}');
    print('Segment Count: ${result.segments.length}');
    
    // There should be a single WALK segment
    expect(result.segments.length, equals(1));
    final segment = result.segments.first;
    expect(segment.lineId, equals('WALK'));
    expect(segment.exit?.exitCode, equals('4'));
    print('Exit code used: ${segment.exit?.exitCode}');
    
    // Verify coordinates match our direct elevated Skywalk (3 points)
    expect(segment.walkingPath, isNotNull);
    print('Walking Path Coordinates Count: ${segment.walkingPath!.length}');
    for (int i = 0; i < segment.walkingPath!.length; i++) {
      print('  Point $i: ${segment.walkingPath![i].latitude}, ${segment.walkingPath![i].longitude}');
    }
    expect(segment.walkingPath!.length, equals(3));
    expect(segment.walkingPath!.first.latitude, equals(13.74621));
    expect(segment.walkingPath!.last.latitude, equals(13.7455));
    
    // Verify custom skywalk instructions
    print('Instructions (TH): ${segment.instructionsTh}');
    print('Instructions (EN): ${segment.instructionsEn}');
    expect(segment.instructionsTh, contains('Skywalk'));
    expect(segment.instructionsTh, contains('ไม่ลงระดับดิน'));
    expect(segment.instructionsEn, contains('elevated skywalk'));
    print('======================================');
  });

  test('Verify Route Calculation and Walking Instructions between Charoen Nakhon and ICONSIAM', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    
    final g2Station = repo.getStation('BTS_G2') as Station?;
    final iconsiamLandmark = repo.landmarks.firstWhere((l) => l.id == 'LM_ICONSIAM');
    
    expect(g2Station, isNotNull);
    expect(iconsiamLandmark, isNotNull);
    
    final searchVm = container.read(searchViewModelProvider.notifier);
    
    await searchVm.setOrigin(g2Station!);
    await searchVm.setDestination(iconsiamLandmark);
    
    final state = container.read(searchViewModelProvider);
    expect(state.error, isNull);
    expect(state.routeResult, isNotNull);
    
    final result = state.routeResult!;
    print('======================================');
    print('ROUTE: Charoen Nakhon (BTS_G2) -> ICONSIAM');
    print('======================================');
    print('Total Minutes: ${result.totalMinutes}');
    print('Segment Count: ${result.segments.length}');
    
    // There should be a single WALK segment
    expect(result.segments.length, equals(1));
    final segment = result.segments.first;
    expect(segment.lineId, equals('WALK'));
    expect(segment.exit?.exitCode, equals('1'));
    print('Exit code used: ${segment.exit?.exitCode}');
    
    // Verify coordinates match our direct elevated connection bridge (2 points)
    expect(segment.walkingPath, isNotNull);
    print('Walking Path Coordinates Count: ${segment.walkingPath!.length}');
    for (int i = 0; i < segment.walkingPath!.length; i++) {
      print('  Point $i: ${segment.walkingPath![i].latitude}, ${segment.walkingPath![i].longitude}');
    }
    expect(segment.walkingPath!.length, equals(2));
    expect(segment.walkingPath!.first.latitude, equals(13.72665));
    expect(segment.walkingPath!.last.latitude, equals(13.7266));
    
    // Verify custom instructions
    print('Instructions (TH): ${segment.instructionsTh}');
    print('Instructions (EN): ${segment.instructionsEn}');
    expect(segment.instructionsTh, contains('ทางเชื่อมยกระดับ'));
    expect(segment.instructionsTh, contains('ไม่ลงระดับดิน'));
    expect(segment.instructionsEn, contains('elevated connection bridge'));
    print('======================================');
  });

  test('Verify Route Calculation and Walking Instructions between Chit Lom and CentralWorld', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    
    final e1Station = repo.getStation('BTS_E1') as Station?;
    final centralWorldLandmark = repo.landmarks.firstWhere((l) => l.id == 'LM_CENTRALWORLD');
    
    expect(e1Station, isNotNull);
    expect(centralWorldLandmark, isNotNull);
    
    final searchVm = container.read(searchViewModelProvider.notifier);
    await searchVm.setOrigin(e1Station!);
    await searchVm.setDestination(centralWorldLandmark);
    
    final state = container.read(searchViewModelProvider);
    expect(state.error, isNull);
    expect(state.routeResult, isNotNull);
    
    final result = state.routeResult!;
    expect(result.segments.length, equals(1));
    final segment = result.segments.first;
    expect(segment.lineId, equals('WALK'));
    expect(segment.exit?.exitCode, equals('6'));
    expect(segment.instructionsTh, contains('Ratchaprasong Skywalk'));
  });

  test('Verify Route Calculation and Walking Instructions between Phrom Phong and EmSphere', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    
    final e5Station = repo.getStation('BTS_E5') as Station?;
    final emSphereLandmark = repo.landmarks.firstWhere((l) => l.id == 'LM_EMSPHERE');
    
    expect(e5Station, isNotNull);
    expect(emSphereLandmark, isNotNull);
    
    final searchVm = container.read(searchViewModelProvider.notifier);
    await searchVm.setOrigin(e5Station!);
    await searchVm.setDestination(emSphereLandmark);
    
    final state = container.read(searchViewModelProvider);
    expect(state.error, isNull);
    expect(state.routeResult, isNotNull);
    
    final result = state.routeResult!;
    expect(result.segments.length, equals(1));
    final segment = result.segments.first;
    expect(segment.lineId, equals('WALK'));
    expect(segment.exit?.exitCode, equals('6'));
    expect(segment.instructionsTh, contains('เอ็มสเฟียร์โดยตรง'));
    expect(segment.instructionsEn, contains('EmSphere via the elevated skywalk'));
  });

  test('Verify Route Calculation and Walking Instructions to Siam Paragon', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    final repo = container.read(transitRepositoryProvider);
    await repo.initialize();
    
    final cenStation = repo.getStation('BTS_CEN') as Station?;
    final w1Station = repo.getStation('BTS_W1') as Station?;
    final paragonLandmark = repo.landmarks.firstWhere((l) => l.id == 'LM_PARAGON');
    
    expect(cenStation, isNotNull);
    expect(w1Station, isNotNull);
    expect(paragonLandmark, isNotNull);
    
    final searchVm = container.read(searchViewModelProvider.notifier);
    
    // 1. Siam to Paragon
    await searchVm.setOrigin(cenStation!);
    await searchVm.setDestination(paragonLandmark);
    var state = container.read(searchViewModelProvider);
    expect(state.routeResult!.segments.first.instructionsTh, contains('สยามพารากอน (ทางออก 3, 5 หรือ 6)'));
    
    // 2. National Stadium to Paragon
    await searchVm.setOrigin(w1Station!);
    await searchVm.setDestination(paragonLandmark);
    state = container.read(searchViewModelProvider);
    expect(state.saverRoute, isNotNull);
    expect(state.saverRoute!.segments.first.instructionsTh, contains('Siam Discovery และ Siam Center'));
  });
}
