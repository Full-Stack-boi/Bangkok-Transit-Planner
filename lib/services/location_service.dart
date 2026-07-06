import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/station.dart';
import '../providers/location_providers.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Service for handling GPS permissions, user location, and proximity detection
class LocationService {
  final Ref? _ref;

  LocationService([this._ref]);
  /// Request location permissions from the user
  Future<bool> requestLocationPermission() async {
    if (kIsWeb) {
      final status = await Geolocator.requestPermission();
      return status == LocationPermission.whileInUse || status == LocationPermission.always;
    }
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    if (kIsWeb) {
      final status = await Geolocator.checkPermission();
      return status == LocationPermission.whileInUse || status == LocationPermission.always;
    }
    return await Permission.location.isGranted;
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Open Android/iOS App settings screen directly
  Future<bool> openSettings() async {
    if (kIsWeb) return false;
    return await openAppSettings();
  }

  /// Get user's current position (returns null if disabled or denied)
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if simulation mode is active in debug mode
      if (kDebugMode && _ref != null) {
        final mockPos = _ref.read(mockLocationProvider);
        if (mockPos != null) {
          AppLogger.info('Using simulated mock location: ${mockPos.latitude}, ${mockPos.longitude}');
          return mockPos;
        }
      }

      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        AppLogger.info('GPS Location Services are globally disabled in the device settings.');
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        AppLogger.info('Location permission check returned denied or deniedForever.');
        return null;
      }

      // Try last known position first (instant and highly reliable on emulators)
      // Note: getLastKnownPosition is not supported on Web.
      if (!kIsWeb) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          AppLogger.info('Using last known position: ${lastKnown.latitude}, ${lastKnown.longitude}');
          return lastKnown;
        }
      }

      // Fetch fresh coordinates
      AppLogger.info('Fetching fresh GPS coordinates...');
      // Increasing timeout for web since browsers can be slow on first lock
      const fetchTimeout = Duration(seconds: 15);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb 
          ? const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 12),
            )
          : AndroidSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 10),
              forceLocationManager: false,
            ),
      ).timeout(fetchTimeout, onTimeout: () {
        AppLogger.info('GPS location fetch timed out after ${fetchTimeout.inSeconds}s.');
        throw TimeoutException('GPS timeout');
      });

      return position;
    } catch (e) {
      AppLogger.error('Failed to get current location: $e', error: e);
      return null;
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
