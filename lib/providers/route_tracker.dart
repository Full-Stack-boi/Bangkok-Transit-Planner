import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_result.dart';
import '../models/station.dart';

class RouteTrackerState {
  final RouteResult? activeRoute;
  final bool isActive;
  final int currentSegmentIndex;
  final int currentStationIndex; // Index within the current segment's stations list
  final bool isSimulation;
  final bool hasArrived;

  const RouteTrackerState({
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

  List<Station> get currentSegmentStations {
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

class RouteTracker extends StateNotifier<RouteTrackerState> {
  StreamSubscription<Position>? _positionSubscription;

  RouteTracker() : super(const RouteTrackerState());

  void startTracking(RouteResult route, {bool simulation = false}) {
    state = RouteTrackerState(
      activeRoute: route,
      isActive: true,
      currentSegmentIndex: 0,
      currentStationIndex: 0,
      isSimulation: simulation,
      hasArrived: false,
    );

    _positionSubscription?.cancel();
    if (!simulation) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        updateLocation(position);
      });
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    state = const RouteTrackerState();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void toggleSimulation(bool enable) {
    state = state.copyWith(isSimulation: enable);
  }

  void advanceSimulation() {
    if (state.activeRoute == null || !state.isActive || state.hasArrived) return;

    final stations = state.currentSegmentStations;
    if (stations.isNotEmpty && state.currentStationIndex < stations.length - 1) {
      state = state.copyWith(currentStationIndex: state.currentStationIndex + 1);
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
    } else {
      state = state.copyWith(hasArrived: true);
    }
  }

  void updateLocation(Position position) {
    if (state.activeRoute == null || !state.isActive || state.hasArrived) return;

    // Proximity threshold of 200 meters to trigger station arrival
    const double threshold = 200.0;

    final stations = state.currentSegmentStations;
    if (stations.isEmpty) return;

    // Check if we are close to any subsequent station in the current segment
    for (int i = state.currentStationIndex + 1; i < stations.length; i++) {
      final station = stations[i];
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        station.lat,
        station.lng,
      );
      if (dist <= threshold) {
        if (i == stations.length - 1) {
          _advanceSegment();
        } else {
          state = state.copyWith(currentStationIndex: i);
        }
        break;
      }
    }
  }
}

final routeTrackerProvider = StateNotifierProvider<RouteTracker, RouteTrackerState>((ref) {
  return RouteTracker();
});
