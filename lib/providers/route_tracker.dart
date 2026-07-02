import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_result.dart';
import '../models/station.dart';
import '../services/journey_activity_service.dart';
import 'providers.dart';

class RouteTrackerState {
  final RouteResult? activeRoute;
  final bool isActive;
  final int currentSegmentIndex;
  final int currentStationIndex; // Index within the current segment's stations list
  final bool isSimulation;
  final bool hasArrived;

  RouteTrackerState({
    this.activeRoute,
    this.isActive = false,
    this.currentSegmentIndex = 0,
    this.currentStationIndex = 0,
    this.isSimulation = false,
    this.hasArrived = false,
  });

  RouteSegment? get currentSegment {
    if (activeRoute == null || !isActive) return null;
    if (currentSegmentIndex < 0 || currentSegmentIndex >= activeRoute!.segments.length) return null;
    return activeRoute!.segments[currentSegmentIndex];
  }

  late final List<Station> currentSegmentStations = _buildStations();

  List<Station> _buildStations() {
    final segment = currentSegment;
    if (segment == null) return [];
    final list = <Station>[];
    if (segment.fromStation is Station) {
      list.add(segment.fromStation as Station);
    }
    list.addAll(segment.intermediateStations);
    if (segment.toStation is Station) {
      list.add(segment.toStation as Station);
    }
    return list;
  }

  Station? get currentStation {
    final stations = currentSegmentStations;
    if (stations.isEmpty || currentStationIndex < 0 || currentStationIndex >= stations.length) return null;
    return stations[currentStationIndex];
  }

  Station? get nextStation {
    final stations = currentSegmentStations;
    if (stations.isNotEmpty && currentStationIndex < stations.length - 1) {
      return stations[currentStationIndex + 1];
    }
    // Check if there is a next segment
    final route = activeRoute;
    if (route != null && currentSegmentIndex < route.segments.length - 1) {
      final nextSeg = route.segments[currentSegmentIndex + 1];
      if (nextSeg.fromStation is Station) {
        return nextSeg.fromStation as Station;
      }
    }
    return null;
  }

  RouteTrackerState copyWith({
    RouteResult? activeRoute,
    bool? isActive,
    int? currentSegmentIndex,
    int? currentStationIndex,
    bool? isSimulation,
    bool? hasArrived,
  }) {
    return RouteTrackerState(
      activeRoute: activeRoute ?? this.activeRoute,
      isActive: isActive ?? this.isActive,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      currentStationIndex: currentStationIndex ?? this.currentStationIndex,
      isSimulation: isSimulation ?? this.isSimulation,
      hasArrived: hasArrived ?? this.hasArrived,
    );
  }
}

class RouteTracker extends Notifier<RouteTrackerState> {
  StreamSubscription<Position>? _positionSubscription;

  @override
  RouteTrackerState build() {
    ref.onDispose(() {
      _positionSubscription?.cancel();
    });
    return RouteTrackerState();
  }

  void _setupActionChannelListener() {
    try {
      const channel = MethodChannel('bkktransit/journey_actions');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'ACTION_NEXT_STATION') {
          advanceSimulation();
        } else if (call.method == 'ACTION_STOP_JOURNEY') {
          stopTracking();
        }
      });
    } catch (e) {
      debugPrint("Skipping action channel handler setup in unit test: $e");
    }
  }

  void _subscribeToPositionStream() {
    _positionSubscription?.cancel();
    if (state.isSimulation || !state.isActive || state.hasArrived) return;

    final segment = state.currentSegment;
    final isWalk = segment?.lineId == 'WALK';

    LocationSettings settings;
    if (kIsWeb) {
      settings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: isWalk ? 15 : 30,
        intervalDuration: Duration(seconds: isWalk ? 10 : 8),
      );
    } else {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: isWalk ? 15 : 30,
        activityType: isWalk ? ActivityType.fitness : ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) {
        updateLocation(position);
      },
      onError: (error) {
        debugPrint("Location stream error (likely location service disabled): $error");
      },
      cancelOnError: false,
    );
  }

  void startTracking(RouteResult route, {bool simulation = false}) {
    state = RouteTrackerState(
      activeRoute: route,
      isActive: true,
      currentSegmentIndex: 0,
      currentStationIndex: 0,
      isSimulation: simulation,
      hasArrived: false,
    );

    _setupActionChannelListener();
    final t = ref.read(translationsProvider);
    JourneyActivityService.start(state, t: t);

    if (!simulation) {
      _subscribeToPositionStream();
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    try {
      const channel = MethodChannel('bkktransit/journey_actions');
      channel.setMethodCallHandler(null);
    } catch (e) {
      // Ignore missing binary messenger in unit tests
    }
    
    JourneyActivityService.stop();
    state = RouteTrackerState();
  }

  void toggleSimulation(bool enable) {
    state = state.copyWith(isSimulation: enable);
  }

  void advanceSimulation() {
    if (state.activeRoute == null || !state.isActive || state.hasArrived) return;

    final stations = state.currentSegmentStations;
    if (stations.isNotEmpty && state.currentStationIndex < stations.length - 1) {
      state = state.copyWith(currentStationIndex: state.currentStationIndex + 1);
      final t = ref.read(translationsProvider);
      JourneyActivityService.update(state, t: t);
    } else {
      _advanceSegment();
    }
  }

  void _advanceSegment() {
    final activeRoute = state.activeRoute;
    if (activeRoute == null) return;

    if (state.currentSegmentIndex < activeRoute.segments.length - 1) {
      state = state.copyWith(
        currentSegmentIndex: state.currentSegmentIndex + 1,
        currentStationIndex: 0,
      );
      
      if (!state.isSimulation) {
        _subscribeToPositionStream();
      }
      final t = ref.read(translationsProvider);
      JourneyActivityService.update(state, t: t);
    } else {
      state = state.copyWith(hasArrived: true);
      JourneyActivityService.stop();
    }
  }

  void updateLocation(Position position) {
    if (state.activeRoute == null || !state.isActive || state.hasArrived) return;

    final segment = state.currentSegment;
    if (segment == null) return;

    final isWalk = segment.lineId == 'WALK';

    if (isWalk) {
      final to = segment.toStation;
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        to.lat,
        to.lng,
      );

      final t = ref.read(translationsProvider);
      JourneyActivityService.update(
        state,
        speedKmh: position.speed * 3.6,
        walkMeters: dist.round(),
        t: t,
      );

      if (dist <= 80.0) {
        _advanceSegment();
      }
    } else {
      final stations = state.currentSegmentStations;
      if (stations.isEmpty) {
        final dist = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          segment.toStation.lat,
          segment.toStation.lng,
        );
        
        final t = ref.read(translationsProvider);
        JourneyActivityService.update(
          state,
          speedKmh: position.speed * 3.6,
          t: t,
        );

        if (dist <= 150.0) {
          _advanceSegment();
        }
        return;
      }

      final nextIdx = state.currentStationIndex + 1;
      if (nextIdx >= stations.length) {
        final lastStation = stations.last;
        final dist = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lastStation.lat,
          lastStation.lng,
        );
        
        final t = ref.read(translationsProvider);
        JourneyActivityService.update(
          state,
          speedKmh: position.speed * 3.6,
          t: t,
        );

        if (dist <= 150.0) {
          _advanceSegment();
        }
        return;
      }

      final next = stations[nextIdx];
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        next.lat,
        next.lng,
      );

      final t = ref.read(translationsProvider);
      JourneyActivityService.update(
        state,
        speedKmh: position.speed * 3.6,
        t: t,
      );

      if (dist <= 150.0) {
        if (nextIdx == stations.length - 1) {
          _advanceSegment();
        } else {
          state = state.copyWith(currentStationIndex: nextIdx);
          final t = ref.read(translationsProvider);
          JourneyActivityService.update(state, speedKmh: position.speed * 3.6, t: t);
        }
      }
    }
  }
}

final routeTrackerProvider = NotifierProvider<RouteTracker, RouteTrackerState>(() {
  return RouteTracker();
});
