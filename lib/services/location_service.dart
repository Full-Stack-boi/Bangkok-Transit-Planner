import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/station.dart';

/// Service for handling GPS permissions, user location, and proximity detection
class LocationService {
  /// Request location permissions from the user
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    return await Permission.location.isGranted;
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Open Android/iOS App settings screen directly
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Get user's current position (returns null if disabled or denied)
  Future<Position?> getCurrentPosition() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        print('GPS Location Services are globally disabled in the device settings.');
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('Location permission check returned denied or deniedForever.');
        return null;
      }

      // Try last known position first (instant and highly reliable on emulators)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        print('Using last known position: ${lastKnown.latitude}, ${lastKnown.longitude}');
        return lastKnown;
      }

      // Fetch fresh coordinates if no last known position is cached
      print('Fetching fresh GPS coordinates with forceLocationManager: true...');
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
          forceLocationManager: true,
        ),
      );
    } catch (e) {
      print('Failed to get current location: $e');
      print('GPS Fallback triggered on emulator: Using TNI mock coordinates (13.7380062, 100.6283891)');
      return Position(
        latitude: 13.7380062,
        longitude: 100.6283891,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  /// Calculate distance in meters between two points
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Find the closest station within a threshold (e.g. 200 meters)
  Station? findNearbyStation(Position position, List<Station> stations, {double thresholdMeters = 200.0}) {
    Station? closestStation;
    double minDistance = double.infinity;

    for (final station in stations) {
      final dist = calculateDistance(position.latitude, position.longitude, station.lat, station.lng);
      if (dist <= thresholdMeters && dist < minDistance) {
        minDistance = dist;
        closestStation = station;
      }
    }

    return closestStation;
  }

  /// Find up to N closest stations within a relative distance threshold
  /// Matches the closest station distance D, and includes others if they are within D + 1000m (minimum radius 2000m)
  List<MapEntry<Station, double>> findRelativeNearestStations(
    Position position,
    List<Station> stations, {
    int maxCount = 5,
  }) {
    if (stations.isEmpty) return [];

    final list = <MapEntry<Station, double>>[];
    for (final station in stations) {
      final dist = calculateDistance(position.latitude, position.longitude, station.lat, station.lng);
      list.add(MapEntry(station, dist));
    }
    
    // Sort all by distance
    list.sort((a, b) => a.value.compareTo(b.value));

    if (list.isEmpty) return [];

    // The closest distance D
    final closestDist = list.first.value;

    // Relative distance threshold: D + 1000m, but at least 2000m
    final double relativeThreshold = closestDist < 1000.0 ? 2000.0 : closestDist + 1000.0;

    // Filter by threshold and take up to maxCount
    return list
        .where((entry) => entry.value <= relativeThreshold)
        .take(maxCount)
        .toList();
  }
}
