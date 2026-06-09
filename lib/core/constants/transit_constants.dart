/// Transit system constants for Bangkok rail network
class TransitConstants {
  TransitConstants._();

  // ─── Peak Hours ───
  static const int morningPeakStart = 7;  // 07:00
  static const int morningPeakEnd = 9;    // 09:00
  static const int eveningPeakStart = 17; // 17:00
  static const int eveningPeakEnd = 19;   // 19:00

  // ─── GPS Passive Crowd Detection ───
  static const double stationProximityMeters = 200.0;
  static const Duration crowdReportExpiry = Duration(minutes: 15);

  // ─── Train Intervals (minutes) ───
  // Peak
  static const int btsPeakInterval = 3;
  static const int mrtBluePeakInterval = 3;
  static const int mrtPurplePeakInterval = 5;
  static const int mrtYellowPeakInterval = 5;
  static const int arlPeakInterval = 12;
  static const int btsGoldPeakInterval = 5;

  // Off-peak
  static const int btsOffPeakInterval = 6;
  static const int mrtBlueOffPeakInterval = 5;
  static const int mrtPurpleOffPeakInterval = 7;
  static const int mrtYellowOffPeakInterval = 8;
  static const int arlOffPeakInterval = 15;
  static const int btsGoldOffPeakInterval = 10;

  // ─── Average time between stations (minutes) ───
  static const double avgTimeBetweenStations = 2.0;
  static const double transferWalkingTime = 5.0; // minutes to walk between platforms

  /// Check if the given time is within peak hours
  static bool isPeakHour(DateTime time) {
    final hour = time.hour;
    return (hour >= morningPeakStart && hour < morningPeakEnd) ||
           (hour >= eveningPeakStart && hour < eveningPeakEnd);
  }

  /// Get train interval in minutes for a line at a given time
  static int getInterval(String lineId, DateTime time) {
    final isPeak = isPeakHour(time);
    switch (lineId) {
      case 'BTS_SUKHUMVIT':
      case 'BTS_SILOM':
        return isPeak ? btsPeakInterval : btsOffPeakInterval;
      case 'BTS_GOLD':
        return isPeak ? btsGoldPeakInterval : btsGoldOffPeakInterval;
      case 'MRT_BLUE':
        return isPeak ? mrtBluePeakInterval : mrtBlueOffPeakInterval;
      case 'MRT_PURPLE':
        return isPeak ? mrtPurplePeakInterval : mrtPurpleOffPeakInterval;
      case 'MRT_YELLOW':
        return isPeak ? mrtYellowPeakInterval : mrtYellowOffPeakInterval;
      case 'ARL':
        return isPeak ? arlPeakInterval : arlOffPeakInterval;
      default:
        return 5;
    }
  }
}
