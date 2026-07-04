import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';
import 'package:bkk_transit_planner/features/search/search_view_model.dart';
import 'package:bkk_transit_planner/providers/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MockTransitRepository extends TransitRepository {
  @override
  Future<CustomLocation?> resolveOnlinePlaceAsync(CustomLocation place) async {
    return place;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testSharedPreferencesInstance = await SharedPreferences.getInstance();
  });

  test('Verify Dynamic Entrance Resolution based on Route Origin', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = MockTransitRepository();
    await repo.initialize();

    print('Initialized Repository Sizes:');
    print('  Stations: ${repo.stations.length}');
    print('  Exits: ${repo.exits.length}');
    print('  Lines: ${repo.lines.length}');
    print('  Landmarks: ${repo.landmarks.length}');

    // Lumphini Park with multiple candidate entrances:
    // Entrance 1 (near MRT Lumphini BL25): 13.726258, 100.545366
    // Entrance 2 (near MRT Si Lom BL26): 13.7290159, 100.5367044
    final lumpiniPark = CustomLocation(
      id: 'OSM_LUMPINI',
      nameTh: 'สวนลุมพินี',
      nameEn: 'Lumphini Park',
      nearestStationId: 'MRT_BL25', // Default fallback
      walkingMinutes: 1.0,
      lat: 13.7313,
      lng: 100.5414,
      entrances: const [
        LatLng(13.726258, 100.545366), // Near MRT Lumphini
        LatLng(13.7290159, 100.5367044), // Near MRT Si Lom
      ],
    );

    final container = ProviderContainer(
      overrides: [transitRepositoryProvider.overrideWithValue(repo)],
    );

    // Keep the auto-dispose provider alive by listening to it
    final subscription = container.listen(searchViewModelProvider, (_, _) {});

    final viewModel = container.read(searchViewModelProvider.notifier);

    // Test Case 1: Route from Lat Krabang (ARL_A2)
    // Lat Krabang -> ... -> MRT Lumphini (BL25) is closer than MRT Si Lom (BL26)
    print('Testing Route 1: Lat Krabang (ARL_A2) to Lumphini Park...');
    final latKrabang = repo.getStation('ARL_A2')!;
    final routeToBL25 = repo.findRoute('ARL_A2', 'MRT_BL25');
    final routeToS1 = repo.findRoute('ARL_A2', 'BTS_S1');
    final routeToBL26 = repo.findRoute('ARL_A2', 'MRT_BL26');
    print(
      'Dijkstra to MRT Lumphini (BL25): weight: ${routeToBL25?.totalWeight}, path: ${routeToBL25?.path.map((s) => s.stationId).toList()}',
    );
    print(
      'Dijkstra to BTS Ratchadamri (S1): weight: ${routeToS1?.totalWeight}, path: ${routeToS1?.path.map((s) => s.stationId).toList()}',
    );
    print(
      'Dijkstra to MRT Si Lom (BL26): weight: ${routeToBL26?.totalWeight}, path: ${routeToBL26?.path.map((s) => s.stationId).toList()}',
    );
    await viewModel.setOrigin(latKrabang);
    await viewModel.setDestination(lumpiniPark);

    final state1 = container.read(searchViewModelProvider);
    print('DEBUG: State 1 Origin: ${state1.origin?.id}');
    print('DEBUG: State 1 Destination: ${state1.destination?.id}');
    print('State 1 Error: ${state1.error}');
    expect(state1.routeResult, isNotNull);
    if (state1.routeResult != null) {
      final destSegment = state1.routeResult!.segments.last;
      print('Route 1 Destination Station ID: ${destSegment.toStation.id}');
      print(
        'Route 1 Walk destination coordinates: ${destSegment.toStation.routeLat}, ${destSegment.toStation.routeLng}',
      );

      // Should resolve nearest station to MRT Si Lom (MRT_BL26) because it has shorter walking distance
      expect(
        state1.routeResult!.destination.nearestStationId,
        equals('MRT_BL26'),
      );
      expect(state1.routeResult!.destination.routeLat, equals(13.7290159));
      expect(state1.routeResult!.destination.routeLng, equals(100.5367044));
    }

    // Test Case 2: Walk from MRT Si Lom (MRT_BL26) directly
    // Because we start at MRT Si Lom, the best entrance is the one near MRT Si Lom (Gate 4)
    print('\nTesting Route 2: MRT Si Lom (MRT_BL26) to Lumphini Park...');
    final silom = repo.getStation('MRT_BL26')!;
    await viewModel.setOrigin(silom);
    await viewModel.setDestination(lumpiniPark);

    final state2 = container.read(searchViewModelProvider);
    print('State 2 Error: ${state2.error}');
    expect(state2.routeResult, isNotNull);
    if (state2.routeResult != null) {
      final destSegment = state2.routeResult!.segments.last;
      print('Route 2 Destination Station ID: ${destSegment.toStation.id}');
      print(
        'Route 2 Walk destination coordinates: ${destSegment.toStation.routeLat}, ${destSegment.toStation.routeLng}',
      );

      // Should resolve nearest station to MRT Si Lom (MRT_BL26) because we are already at Si Lom
      expect(
        state2.routeResult!.destination.nearestStationId,
        equals('MRT_BL26'),
      );
      expect(state2.routeResult!.destination.routeLat, equals(13.7290159));
      expect(state2.routeResult!.destination.routeLng, equals(100.5367044));
    }

    subscription.close();
  });
}
