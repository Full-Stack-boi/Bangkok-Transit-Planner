import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import '../providers/route_tracker.dart';
import '../core/theme/transit_colors.dart';
import '../core/constants/translation_helper.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

class JourneyActivityService {
  static final _plugin = LiveActivities();
  static bool _initialized = false;
  static const String _activityId = 'journey_tracking';
  static AppLocalizations _t = AppLocalizations('th');

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;
    try {
      await _plugin.init(appGroupId: 'group.com.bkktransit');
      _initialized = true;
    } catch (e) {
      AppLogger.error('Failed to initialize LiveActivities plugin: $e', error: e);
    }
  }

  static Future<void> start(RouteTrackerState state, {required AppLocalizations t}) async {
    _t = t;
    if (kIsWeb) return;
    await init();
    if (!_initialized) return;
    // Check if device supports Live Activities before attempting to create one
    final enabled = await _plugin.areActivitiesEnabled();
    if (enabled != true) {
      AppLogger.warning('Live Activities not supported or disabled on this device');
      return;
    }
    try {
      final data = _buildPayload(state, speedKmh: 0);
      await _plugin.createActivity(_activityId, data);
    } catch (e) {
      AppLogger.error('Failed to create live activity: $e', error: e);
    }
  }

  static Future<void> update(RouteTrackerState state, {double speedKmh = 0, int walkMeters = 0, AppLocalizations? t}) async {
    if (t != null) {
      _t = t;
    }
    if (kIsWeb) return;
    if (!_initialized) return;
    try {
      final data = _buildPayload(state, speedKmh: speedKmh);
      data['walkMeters'] = walkMeters;
      
      // Update walkText and contentText with the dynamic walking distance
      if (state.currentSegment?.lineId == 'WALK') {
        final walkMetersStr = walkMeters.toString();
        data['walkText'] = _t.journey.walkRemaining(walkMetersStr);
        data['contentText'] = _t.journey.walkRemaining(walkMetersStr);
      }
      
      await _plugin.updateActivity(_activityId, data);
    } catch (e) {
      AppLogger.error('Failed to update live activity: $e', error: e);
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
      AppLogger.error('Failed to end live activity: $e', error: e);
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
    
    final isTh = _t.isTh;
    final isWalk = seg?.lineId == 'WALK';
    final lineId = isWalk ? 'WALK' : (seg?.lineId ?? '');
    final color = TransitColors.getLineColor(lineId);
    final textColor = TransitColors.getLineTextColor(lineId);

    final colorHex = _colorToHex(color);
    final textColorHex = _colorToHex(textColor);

    final currentStnName = isTh
        ? (state.currentStation?.nameTh ?? (seg?.fromStation.nameTh ?? ''))
        : (state.currentStation?.nameEn ?? (seg?.fromStation.nameEn ?? ''));

    final nextStn = state.nextStation;
    final nextStnName = nextStn != null 
        ? (isTh ? nextStn.nameTh : nextStn.nameEn) 
        : (seg?.toStation != null 
            ? (isTh ? seg!.toStation.nameTh : seg!.toStation.nameEn) 
            : _t.journey.arrivedText);

    final destStnName = isTh 
        ? (route?.destination.nameTh ?? '') 
        : (route?.destination.nameEn ?? '');

    final directionText = _t.journey.headingTo(destStnName);
    final walkText = _t.journey.walkRemaining('0');
    final etaText = _t.journey.etaRemaining(etaMinutes.round());
    final speedText = _t.journey.speedMeasure(speedKmh.toStringAsFixed(1));
    final travelModeText = isWalk ? _t.journey.walkingAction : _t.journey.transitRideAction;
    final contentText = isWalk ? _t.journey.walkRemaining('0') : _t.journey.headingTo(destStnName);

    return {
      'lineId': lineId,
      'lineName': isWalk 
          ? _t.journey.walkingConnection
          : (seg?.lineName ?? _t.journey.travelingStatus),
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
      
      // Localized notification strings
      'directionText': directionText,
      'walkText': walkText,
      'etaText': etaText,
      'speedText': speedText,
      'travelModeText': travelModeText,
      'walkingAction': _t.journey.walkingAction,
      'contentText': contentText,
    };
  }
}
