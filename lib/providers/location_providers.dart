import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// WARNING: MOCK LOCATION PROVIDER FOR DEVELOPMENT & TESTING ONLY.
// To prevent accidental leaks in Production/PlayStore releases, all simulation
// functions and persistence loading are guarded by 'kDebugMode'.
// In release mode, the provider will always report 'null' (real GPS).
// ============================================================================

final mockLocationProvider = StateNotifierProvider<MockLocationNotifier, Position?>((ref) {
  return MockLocationNotifier();
});

class MockLocationNotifier extends StateNotifier<Position?> {
  MockLocationNotifier() : super(null) {
    if (kDebugMode) {
      _loadMockLocation();
    }
  }

  Future<void> _loadMockLocation() async {
    // Only load persisted mock coordinates if in debug mode
    if (!kDebugMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('mock_latitude');
      final lng = prefs.getDouble('mock_longitude');
      if (lat != null && lng != null) {
        state = Position(
          latitude: lat,
          longitude: lng,
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
    } catch (_) {}
  }

  Future<void> setMockLocation(double latitude, double longitude) async {
    // Hard guard to completely block mocking in production/release mode
    if (!kDebugMode) return;

    final pos = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    state = pos;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('mock_latitude', latitude);
      await prefs.setDouble('mock_longitude', longitude);
    } catch (_) {}
  }

  Future<void> clearMockLocation() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mock_latitude');
      await prefs.remove('mock_longitude');
    } catch (_) {}
  }
}
