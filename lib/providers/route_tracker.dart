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

    final segment = state.currentSegment;
    if (segment == null) return;

    final isWalk = segment.lineId == 'WALK';

    if (isWalk) {
      // For walking segments, track progress towards the destination of the segment
      final to = segment.toStation;
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        to.lat,
        to.lng,
      );

      // Walking arrival threshold: 80 meters
      if (dist <= 80.0) {
        _advanceSegment();
      }
    } else {
      // For transit line segments, track progress station-by-station
      final stations = state.currentSegmentStations;
      if (stations.isEmpty) {
        // Fallback: if somehow stations list is empty, check distance to segment destination
        final dist = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          segment.toStation.lat,
          segment.toStation.lng,
        );
        if (dist <= 150.0) {
          _advanceSegment();
        }
        return;
      }

      final nextIdx = state.currentStationIndex + 1;
      if (nextIdx >= stations.length) {
        // We are already at the last station of this segment
        // Check if we are close to the final station to advance segment
        final lastStation = stations.last;
        final dist = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lastStation.lat,
          lastStation.lng,
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

      // Transit station arrival threshold: 150 meters
      if (dist <= 150.0) {
        if (nextIdx == stations.length - 1) {
          _advanceSegment();
        } else {
          state = state.copyWith(currentStationIndex: nextIdx);
        }
      }
    }
  }
}

final routeTrackerProvider = NotifierProvider<RouteTracker, RouteTrackerState>(() {
  return RouteTracker();
});
