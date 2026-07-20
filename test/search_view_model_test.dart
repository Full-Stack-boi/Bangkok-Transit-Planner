import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bkk_transit_planner/providers/providers.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/models/line.dart';
import 'package:bkk_transit_planner/services/dijkstra_planner.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/features/search/search_view_model.dart';

class MockSearchTransitRepository extends TransitRepository {
  final List<Station> _mockStations = [
    const Station(
      id: 'BTS_A',
      code: 'N1',
      nameTh: 'สถานีเอ',
      nameEn: 'Station A',
      lat: 13.75,
      lng: 100.52,
      lineId: 'BTS_SUKHUMVIT',
      interchange: [],
    ),
    const Station(
      id: 'BTS_B',
      code: 'N2',
      nameTh: 'สถานีบี',
      nameEn: 'Station B',
      lat: 13.76,
      lng: 100.53,
      lineId: 'BTS_SUKHUMVIT',
      interchange: ['MRT_C'],
    ),
    const Station(
      id: 'MRT_C',
      code: 'BL01',
      nameTh: 'สถานีซี',
      nameEn: 'Station C',
      lat: 13.76,
      lng: 100.53,
      lineId: 'MRT_BLUE',
      interchange: ['BTS_B'],
    ),
    const Station(
      id: 'MRT_D',
      code: 'BL02',
      nameTh: 'สถานีดี',
      nameEn: 'Station D',
      lat: 13.77,
      lng: 100.54,
      lineId: 'MRT_BLUE',
      interchange: [],
    ),
  ];

  @override
  bool get isInitialized => true;

  @override
  List<Station> get stations => _mockStations;

  @override
  List<TransitLine> get lines => [
    const TransitLine(
      id: 'BTS_SUKHUMVIT',
      nameTh: 'สายสุขุมวิท',
      nameEn: 'Sukhumvit Line',
      operator: 'BTS',
      colorHex: '#00FF00',
      stationIds: ['BTS_A', 'BTS_B'],
      bound0Label: 'ไปคูคต',
      bound1Label: 'ไปเคหะฯ',
      isLoop: false,
      peakIntervalMin: 3,
      offPeakIntervalMin: 6,
    ),
    const TransitLine(
      id: 'MRT_BLUE',
      nameTh: 'สายสีน้ำเงิน',
      nameEn: 'Blue Line',
      operator: 'MRT',
      colorHex: '#0000FF',
      stationIds: ['MRT_C', 'MRT_D'],
      bound0Label: 'ไปบางซื่อ',
      bound1Label: 'ไปหลักสอง',
      isLoop: false,
      peakIntervalMin: 4,
      offPeakIntervalMin: 8,
    ),
  ];

  @override
  TransitGraph get graph {
    final g = TransitGraph();
    for (final s in _mockStations) {
      g.addStation(s);
    }
    g.addEdge('BTS_A', 'BTS_B', 'BTS_SUKHUMVIT', weight: 2.0);
    g.addEdge('MRT_C', 'MRT_D', 'MRT_BLUE', weight: 3.0);
    g.addTransferEdge('BTS_B', 'MRT_C', walkingMinutes: 5.0);
    return g;
  }

  @override
  Future<void> initialize() async {}

  @override
  Station? getStation(String id) {
    for (final s in _mockStations) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  TransitLine? getLine(String lineId) {
    return lines.firstWhere((l) => l.id == lineId);
  }

  @override
  DijkstraResult? findRoute(String fromId, String toId, {DateTime? time}) {
    return graph.findShortestPath(fromId, toId);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testSharedPreferencesInstance = await SharedPreferences.getInstance();
  });

  group('SearchViewModel Route Segment Tests', () {
    test('Should calculate transfer route and segments successfully', () async {
      final repo = MockSearchTransitRepository();
      final container = ProviderContainer(
        overrides: [transitRepositoryProvider.overrideWithValue(repo)],
      );

      final searchVm = container.read(searchViewModelProvider.notifier);
      final stationA = repo.getStation('BTS_A')!;
      final stationD = repo.getStation('MRT_D')!;

      // Act
      await searchVm.setOrigin(stationA);
      await searchVm.setDestination(stationD);

      // Assert
      final state = container.read(searchViewModelProvider);
      expect(state.error, isNull);
      expect(state.routeResult, isNotNull);

      final result = state.routeResult!;
      expect(result.segments.length, equals(2)); // BTS Segment and MRT Segment
      expect(
        result.transfers.length,
        equals(1),
      ); // 1 Transfer between BTS_B and MRT_C

      // First segment: BTS_A -> BTS_B
      expect(result.segments[0].lineId, equals('BTS_SUKHUMVIT'));
      expect(result.segments[0].fromStation.id, equals('BTS_A'));
      expect(result.segments[0].toStation.id, equals('BTS_B'));

      // Second segment: MRT_C -> MRT_D
      expect(result.segments[1].lineId, equals('MRT_BLUE'));
      expect(result.segments[1].fromStation.id, equals('MRT_C'));
      expect(result.segments[1].toStation.id, equals('MRT_D'));
    });

    test(
      'Should handle swap and calculate routes without throwing errors',
      () async {
        final repo = MockSearchTransitRepository();
        final container = ProviderContainer(
          overrides: [transitRepositoryProvider.overrideWithValue(repo)],
        );

        final searchVm = container.read(searchViewModelProvider.notifier);
        final stationA = repo.getStation('BTS_A')!;
        final stationD = repo.getStation('MRT_D')!;

        // Act
        await searchVm.setOrigin(stationA);
        await searchVm.setDestination(stationD);

        // Swap Origin and Destination
        searchVm.swapStations();

        // Assert
        final state = container.read(searchViewModelProvider);
        expect(state.error, isNull);
        expect(state.routeResult, isNotNull);

        final result = state.routeResult!;
        // Origin is now MRT_D, Destination is BTS_A
        expect(result.origin.id, equals('MRT_D'));
        expect(result.destination.id, equals('BTS_A'));

        expect(result.segments.length, equals(2));
        expect(result.transfers.length, equals(1));

        // First segment: MRT_D -> MRT_C
        expect(result.segments[0].lineId, equals('MRT_BLUE'));
        expect(result.segments[0].fromStation.id, equals('MRT_D'));
        expect(result.segments[0].toStation.id, equals('MRT_C'));

        // Second segment: BTS_B -> BTS_A
        expect(result.segments[1].lineId, equals('BTS_SUKHUMVIT'));
        expect(result.segments[1].fromStation.id, equals('BTS_B'));
        expect(result.segments[1].toStation.id, equals('BTS_A'));
      },
    );

    test('Should support selecting recommended and saver route types', () async {
      final repo = MockSearchTransitRepository();
      final container = ProviderContainer(
        overrides: [transitRepositoryProvider.overrideWithValue(repo)],
      );

      final searchVm = container.read(searchViewModelProvider.notifier);
      final stationA = repo.getStation('BTS_A')!;
      final stationD = repo.getStation('MRT_D')!;

      // Act
      await searchVm.setOrigin(stationA);
      await searchVm.setDestination(stationD);

      // Assert initial state
      var state = container.read(searchViewModelProvider);
      expect(state.activeRouteType, equals('recommended'));
      expect(state.routeResult, equals(state.regularRoute));

      // Manually set a mock saver route in state (since mock graph might not trigger the saver route criteria)
      final dummyRoute = state.regularRoute!;
      searchVm.state = state.copyWith(saverRoute: dummyRoute);

      // Select saver route
      searchVm.selectRouteType('saver');
      state = container.read(searchViewModelProvider);
      expect(state.activeRouteType, equals('saver'));
      expect(state.routeResult, equals(dummyRoute));

      // Select recommended route back
      searchVm.selectRouteType('recommended');
      state = container.read(searchViewModelProvider);
      expect(state.activeRouteType, equals('recommended'));
      expect(state.routeResult, equals(state.regularRoute));
    });
  });
}
