import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import '../providers/route_tracker.dart';
import '../core/theme/transit_colors.dart';

class JourneyActivityService {
  static final _plugin = LiveActivities();
  static bool _initialized = false;
  static const String _activityId = 'journey_tracking';

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;
    try {
      await _plugin.init(appGroupId: 'group.com.bkktransit');
      _initialized = true;
    } catch (e) {
      debugPrint("Failed to initialize LiveActivities plugin: $e");
    }
  }

  static Future<void> start(RouteTrackerState state) async {
    if (kIsWeb) return;
    await init();
    if (!_initialized) return;
    try {
      final data = _buildPayload(state, speedKmh: 0);
      await _plugin.createActivity(_activityId, data);
    } catch (e) {
      debugPrint("Failed to create live activity: $e");
    }
  }

  static Future<void> update(RouteTrackerState state, {double speedKmh = 0, int walkMeters = 0}) async {
    if (kIsWeb) return;
    if (!_initialized) return;
    try {
      final data = _buildPayload(state, speedKmh: speedKmh);
      data['walkMeters'] = walkMeters;
      await _plugin.updateActivity(_activityId, data);
    } catch (e) {
      debugPrint("Failed to update live activity: $e");
    }
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    if (!_initialized) return;
    try {
      const channel = MethodChannel('bkktransit/journey_actions');
      await channel.invokeMethod('STOP_FOREGROUND_SERVICE');
    } catch (e) {
      // Ignore if channel is not ready or fails
    }
    try {
      await _plugin.endActivity(_activityId);
    } catch (e) {
      debugPrint("Failed to end live activity: $e");
    }
  }

  static String _colorToHex(Color color) {
    // ignore: deprecated_member_use
    final r = color.red.toRadixString(16).padLeft(2, '0');
    // ignore: deprecated_member_use
    final g = color.green.toRadixString(16).padLeft(2, '0');
    // ignore: deprecated_member_use
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  static Map<String, dynamic> _buildPayload(RouteTrackerState state, {required double speedKmh}) {
    final seg = state.currentSegment;
    
    // Calculate remaining stations
    int remaining = 0;
    final currentStations = state.currentSegmentStations;
    if (currentStations.isNotEmpty) {
      final remainingInCurrent = currentStations.length - 1 - state.currentStationIndex;
      if (remainingInCurrent > 0) {
        remaining += remainingInCurrent;
      }
    }
    final route = state.activeRoute;
    if (route != null) {
      for (int i = state.currentSegmentIndex + 1; i < route.segments.length; i++) {
        final s = route.segments[i];
        if (s.lineId != 'WALK') {
          remaining += s.stationCount;
        }
      }
    }
    
    final total = route?.totalStations ?? 1;
    final done = (total - remaining).clamp(0, total);

    // Calculate ETA in minutes
    double etaMinutes = 0.0;
    if (seg != null) {
      etaMinutes = seg.estimatedMinutes;
      if (currentStations.isNotEmpty) {
        final progressRatio = state.currentStationIndex / currentStations.length;
        etaMinutes = etaMinutes * (1.0 - progressRatio);
      }
      if (route != null) {
        for (int i = state.currentSegmentIndex + 1; i < route.segments.length; i++) {
          etaMinutes += route.segments[i].estimatedMinutes;
        }
      }
    }
    
    final isWalk = seg?.lineId == 'WALK';
    final lineId = isWalk ? 'WALK' : (seg?.lineId ?? '');
    final color = TransitColors.getLineColor(lineId);
    final textColor = TransitColors.getLineTextColor(lineId);

    final colorHex = _colorToHex(color);
    final textColorHex = _colorToHex(textColor);

    final currentStnName = state.currentStation?.nameTh ?? (seg?.fromStation.nameTh ?? '');
    final nextStn = state.nextStation;
    final nextStnName = nextStn != null ? nextStn.nameTh : (seg?.toStation.nameTh ?? 'ถึงจุดหมายแล้ว');
    final destStnName = route?.destination.nameTh ?? '';

    return {
      'lineId': lineId,
      'lineName': isWalk ? 'เดินเท้าเชื่อมต่อ' : (seg?.lineName ?? 'กำลังเดินทาง'),
      'lineColorHex': colorHex,
      'lineTextColorHex': textColorHex,
      'currentStation': currentStnName,
      'nextStation': nextStnName,
      'destinationStation': destStnName,
      'stationsDone': done,
      'stationsTotal': total,
      'walkMeters': 0,
      'etaMinutes': etaMinutes.round(),
      'speedKmh': speedKmh,
      'isWalking': isWalk,
      'isSimulation': state.isSimulation,
    };
  }
}
