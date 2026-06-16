import '../core/constants/transit_constants.dart';

/// Service for calculating next train arrival times
class ScheduleService {
  /// Operating hours per line: {lineId: {weekday: {first, last}, weekend: {first, last}}}
  static const Map<String, Map<String, Map<String, String>>> _operatingHours = {
    'BTS_SUKHUMVIT': {
      'weekday': {'first': '05:15', 'last': '00:00'},
      'weekend': {'first': '05:30', 'last': '00:00'},
    },
    'BTS_SILOM': {
      'weekday': {'first': '05:15', 'last': '00:00'},
      'weekend': {'first': '05:30', 'last': '00:00'},
    },
    'BTS_GOLD': {
      'weekday': {'first': '06:00', 'last': '00:00'},
      'weekend': {'first': '06:00', 'last': '00:00'},
    },
    'MRT_BLUE': {
      'weekday': {'first': '05:30', 'last': '00:00'},
      'weekend': {'first': '05:30', 'last': '00:00'},
    },
    'MRT_PURPLE': {
      'weekday': {'first': '05:30', 'last': '00:00'},
      'weekend': {'first': '05:30', 'last': '00:00'},
    },
    'MRT_YELLOW': {
      'weekday': {'first': '05:30', 'last': '23:30'},
      'weekend': {'first': '05:30', 'last': '23:30'},
    },
    'ARL': {
      'weekday': {'first': '05:30', 'last': '00:00'},
      'weekend': {'first': '05:30', 'last': '00:00'},
    },
  };

  static final Map<String, Map<String, Map<String, int>>> _parsedHours = {};

  /// Get the next train time from now
  /// Returns minutes until next train, or null if service is not running
  int? getMinutesUntilNextTrain(String lineId, {DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final interval = TransitConstants.getInterval(lineId, now);

    if (!isServiceRunning(lineId, now)) return null;

    // Calculate minutes since last round interval
    final minutesSinceHour = now.minute;
    final minutesSinceLastTrain = minutesSinceHour % interval;
    final minutesUntilNext = interval - minutesSinceLastTrain;

    return minutesUntilNext == interval ? 0 : minutesUntilNext;
  }

  /// Check if service is currently running
  bool isServiceRunning(String lineId, DateTime time) {
    if (_parsedHours.isEmpty) {
      for (final line in _operatingHours.entries) {
        _parsedHours[line.key] = {};
        for (final day in line.value.entries) {
          final firstParts = day.value['first']!.split(':');
          final firstMins = int.parse(firstParts[0]) * 60 + int.parse(firstParts[1]);
          final lastParts = day.value['last']!.split(':');
          final lastHour = int.parse(lastParts[0]);
          final lastMins = lastHour == 0 ? 1440 : lastHour * 60;
          _parsedHours[line.key]![day.key] = {'first': firstMins, 'last': lastMins};
        }
      }
    }

    final isWeekend = time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
    final dayType = isWeekend ? 'weekend' : 'weekday';
    final hours = _parsedHours[lineId]?[dayType];

    if (hours == null) return false;

    final currentMinutes = time.hour * 60 + time.minute;
    return currentMinutes >= hours['first']! && currentMinutes < hours['last']!;
  }

  /// Get operating hours text for a line
  String getOperatingHoursText(String lineId, {bool isWeekend = false}) {
    final dayType = isWeekend ? 'weekend' : 'weekday';
    final hours = _operatingHours[lineId]?[dayType];
    if (hours == null) return 'ไม่มีข้อมูล';
    return '${hours['first']} - ${hours['last']}';
  }

  /// Get estimated travel time between two stations
  double getEstimatedTravelTime(int stationCount, {bool includeTransfer = false}) {
    double time = stationCount * TransitConstants.avgTimeBetweenStations;
    if (includeTransfer) {
      time += TransitConstants.transferWalkingTime;
    }
    return time;
  }
}
