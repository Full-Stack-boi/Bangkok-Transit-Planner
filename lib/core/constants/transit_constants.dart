/// Transit system constants for Bangkok rail network
class TransitConstants {
  TransitConstants._();

  // Peak Hours
  static const int morningPeakStart = 7; // 07:00
  static const int morningPeakEnd = 9; // 09:00
  static const int eveningPeakStart = 17; // 17:00
  static const int eveningPeakEnd = 19; // 19:00

  // Line IDs
  static const String kBtsSukhumvit = 'BTS_SUKHUMVIT';
  static const String kBtsSilom = 'BTS_SILOM';
  static const String kBtsGold = 'BTS_GOLD';
  static const String kMrtBlue = 'MRT_BLUE';
  static const String kMrtPurple = 'MRT_PURPLE';
  static const String kMrtYellow = 'MRT_YELLOW';
  static const String kMrtPink = 'MRT_PINK';
  static const String kMrtPinkBranch = 'MRT_PINK_BRANCH';
  static const String kSrtRedNorth = 'SRT_RED_NORTH';
  static const String kSrtRedWest = 'SRT_RED_WEST';
  static const String kArl = 'ARL';
  static const String kWalkLineId = 'WALK';
  static const int kDefaultInterval = 5;
  static const int kLineCount = 8;

  // Critical Station IDs
  static const String kStationMrtThaphraBl01 = 'MRT_BL01';
  static const String kStationMrtThaphraUpperBl33 = 'MRT_BL33';
  static const String kStationBtsSiamCen = 'BTS_CEN';
  static const String kStationBtsSiamSilom = 'BTS_CEN_SILOM';
  static const String kStationMrtAsokBl22 = 'MRT_BL22';
  static const String kStationBtsSukhumvitE4 = 'BTS_E4';

  // Status Strings
  static const String kStatusPendingTh = 'รอยืนยัน';
  static const String kStatusPendingEn = 'Pending';

  // Proximity & Walking
  static const double kInsideStationMeters = 50.0;
  static const int kDwellThresholdMinutes = 10;
  static const int kDwellThresholdMinutesDebug = 1;
  static const double kWalkingSpeedMpm = 80.0;
  static const double kMinWalkMinutes = 1.0;
  static const double kMaxWalkMinutes = 30.0;

  // GPS Passive Crowd Detection
  static const double stationProximityMeters = 200.0;
  static const Duration crowdReportExpiry = Duration(minutes: 15);

  // Train Intervals (minutes)
  // Peak
  static const int btsPeakInterval = 3;
  static const int mrtBluePeakInterval = 3;
  static const int mrtPurplePeakInterval = 5;
  static const int mrtYellowPeakInterval = 5;
  static const int mrtPinkPeakInterval = 5;
  static const int srtRedPeakInterval = 10;
  static const int arlPeakInterval = 12;
  static const int btsGoldPeakInterval = 5;

  // Off-peak
  static const int btsOffPeakInterval = 6;
  static const int mrtBlueOffPeakInterval = 5;
  static const int mrtPurpleOffPeakInterval = 7;
  static const int mrtYellowOffPeakInterval = 8;
  static const int mrtPinkOffPeakInterval = 10;
  static const int srtRedOffPeakInterval = 15;
  static const int arlOffPeakInterval = 15;
  static const int btsGoldOffPeakInterval = 10;

  // Average time between stations (minutes)
  static const double avgTimeBetweenStations = 2.0;
  static const double transferWalkingTime =
      5.0; // minutes to walk between platforms

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
      case kBtsSukhumvit:
      case kBtsSilom:
        return isPeak ? btsPeakInterval : btsOffPeakInterval;
      case kBtsGold:
        return isPeak ? btsGoldPeakInterval : btsGoldOffPeakInterval;
      case kMrtBlue:
        return isPeak ? mrtBluePeakInterval : mrtBlueOffPeakInterval;
      case kMrtPurple:
        return isPeak ? mrtPurplePeakInterval : mrtPurpleOffPeakInterval;
      case kMrtYellow:
        return isPeak ? mrtYellowPeakInterval : mrtYellowOffPeakInterval;
      case kMrtPink:
      case kMrtPinkBranch:
        return isPeak ? mrtPinkPeakInterval : mrtPinkOffPeakInterval;
      case kSrtRedNorth:
      case kSrtRedWest:
        return isPeak ? srtRedPeakInterval : srtRedOffPeakInterval;
      case kArl:
        return isPeak ? arlPeakInterval : arlOffPeakInterval;
      default:
        return kDefaultInterval;
    }
  }
}
