import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/models/route_result.dart';
import 'package:bkk_transit_planner/providers/route_tracker.dart';

void main() {
  group('RouteTracker Tests', () {
    final stationA = const Station(
      id: 'BTS_A',
      code: 'N1',
      nameTh: 'สถานีเอ',
      nameEn: 'Station A',
      lat: 13.75,
      lng: 100.52,
      lineId: 'BTS_SUKHUMVIT',
      interchange: [],
    );

    final stationB = const Station(
      id: 'BTS_B',
      code: 'N2',
      nameTh: 'สถานีบี',
      nameEn: 'Station B',
      lat: 13.76,
      lng: 100.53,
      lineId: 'BTS_SUKHUMVIT',
      interchange: [],
    );

    final mockSegment = RouteSegment(
      lineId: 'BTS_SUKHUMVIT',
      lineName: 'สายสุขุมวิท',
      direction: 'ไปเคหะฯ',
      boundIndex: 1,
      fromStation: stationA,
      toStation: stationB,
      intermediateStations: const [],
      stationCount: 1,
      estimatedMinutes: 3.0,
      fareThb: 15,
    );

    final mockRoute = RouteResult(
      origin: stationA,
      destination: stationB,
      segments: [mockSegment],
      transfers: const [],
      totalMinutes: 3.0,
      totalFareThb: 15,
      totalStations: 2,
      calculatedAt: DateTime.now(),
    );

    test('Should start and stop tracking correctly', () {
      final container = ProviderContainer();
      final tracker = container.read(routeTrackerProvider.notifier);

      expect(container.read(routeTrackerProvider).isActive, isFalse);

      // Start Tracking (Simulation)
      tracker.startTracking(mockRoute, simulation: true);

      final state = container.read(routeTrackerProvider);
      expect(state.isActive, isTrue);
      expect(state.activeRoute, equals(mockRoute));
      expect(state.currentSegmentIndex, equals(0));
      expect(state.currentStationIndex, equals(0));
      expect(state.currentStation?.id, equals('BTS_A'));
      expect(state.nextStation?.id, equals('BTS_B'));
      expect(state.hasArrived, isFalse);

      // Stop Tracking
      tracker.stopTracking();
      expect(container.read(routeTrackerProvider).isActive, isFalse);
      expect(container.read(routeTrackerProvider).activeRoute, isNull);
    });

    test('Should advance simulation step by step until arrival', () {
      final container = ProviderContainer();
      final tracker = container.read(routeTrackerProvider.notifier);

      tracker.startTracking(mockRoute, simulation: true);

      // Current station is A (index 0)
      expect(container.read(routeTrackerProvider).currentStation?.id, equals('BTS_A'));

      // Advance simulation -> should move to station B (index 1)
      tracker.advanceSimulation();
      expect(container.read(routeTrackerProvider).currentStation?.id, equals('BTS_B'));
      expect(container.read(routeTrackerProvider).hasArrived, isFalse);

      // Advance simulation again -> should reach the end (since B is the last station of the last segment)
      tracker.advanceSimulation();
      expect(container.read(routeTrackerProvider).hasArrived, isTrue);
    });

    test('Should advance automatically on location proximity updates', () {
      final container = ProviderContainer();
      final tracker = container.read(routeTrackerProvider.notifier);

      tracker.startTracking(mockRoute, simulation: true);

      // Initial position at station A
      expect(container.read(routeTrackerProvider).currentStation?.id, equals('BTS_A'));

      // Mock user position close to station B (lat: 13.76, lng: 100.53)
      final posNearB = Position(
        latitude: 13.7599, // ~10 meters from station B
        longitude: 100.5301,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      tracker.updateLocation(posNearB);

      // Since station B is the last station of the last segment, it should trigger segment advancement to Arrival
      final state = container.read(routeTrackerProvider);
      expect(state.hasArrived, isTrue);
    });
  });
}
