import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bkk_transit_planner/services/location_service.dart';
import 'package:bkk_transit_planner/models/station.dart';
import 'package:bkk_transit_planner/providers/providers.dart';

void main() {
  group('LocationService Proximity & Geofencing Tests', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
    });

    test('calculateDistance correctly measures distance between Siam and Asok', () {
      // Siam coordinates: 13.7456, 100.5348
      // Asok coordinates: 13.7369, 100.5614
      final distance = locationService.calculateDistance(13.7456, 100.5348, 13.7369, 100.5614);
      
      // The distance should be roughly ~2.9 km (2980 meters)
      expect(distance, closeTo(2980.0, 100.0));
    });

    test('findNearbyStation returns the station if within the strict 50m threshold', () {
      final stations = [
        const Station(
          id: 'BTS_CEN',
          code: 'CEN',
          nameTh: 'สยาม',
          nameEn: 'Siam',
          lat: 13.7456,
          lng: 100.5348,
          lineId: 'BTS_SUKHUMVIT',
          interchange: [],
        ),
      ];

      // Mock position very close to Siam (approx 15 meters away)
      final mockPosition = Position(
        latitude: 13.7456,
        longitude: 100.5349,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final station = locationService.findNearbyStation(
        mockPosition,
        stations,
        thresholdMeters: 50.0,
      );

      expect(station, isNotNull);
      expect(station!.id, equals('BTS_CEN'));
    });

    test('findNearbyStation returns null if the position is outside the 50m threshold', () {
      final stations = [
        const Station(
          id: 'BTS_CEN',
          code: 'CEN',
          nameTh: 'สยาม',
          nameEn: 'Siam',
          lat: 13.7456,
          lng: 100.5348,
          lineId: 'BTS_SUKHUMVIT',
          interchange: [],
        ),
      ];

      // Mock position on the street far from Siam (approx 300 meters away)
      final mockPosition = Position(
        latitude: 13.7430,
        longitude: 100.5348,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final station = locationService.findNearbyStation(
        mockPosition,
        stations,
        thresholdMeters: 50.0,
      );

      expect(station, isNull);
    });

    test('getCurrentPosition returns simulated position if mock location provider is set', () async {
      final mockPosition = Position(
        latitude: 13.7456,
        longitude: 100.5348,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final container = ProviderContainer(
        overrides: [
          mockLocationProvider.overrideWith(() => TestLocationNotifier(mockPosition)),
        ],
      );
      final customLocationService = container.read(locationServiceProvider);

      final result = await customLocationService.getCurrentPosition();
      expect(result, isNotNull);
      expect(result!.latitude, equals(13.7456));
      expect(result.longitude, equals(100.5348));
    });
  });
}

class TestLocationNotifier extends MockLocation {
  final Position initialPosition;

  TestLocationNotifier(this.initialPosition);

  @override
  Position? build() {
    return initialPosition;
  }
}
