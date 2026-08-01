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

  // Critical Station IDs
  static const String kStationMrtThaphraBl01 = 'MRT_BL01';
  static const String kStationMrtThaphraUpperBl33 = 'MRT_BL33';
  static const String kStationBtsSiamCen = 'BTS_CEN';
  static const String kStationBtsSiamSilom = 'BTS_CEN_SILOM';
  static const String kStationMrtAsokBl22 = 'MRT_BL22';
  static const String kStationBtsSukhumvitE4 = 'BTS_E4';
  static const String kStationArlMakkasanA6 = 'ARL_A6';
  static const String kStationMrtPhetchaburiBl21 = 'MRT_BL21';
  static const String kStationBtsPhayathaiN2 = 'BTS_N2';
  static const String kStationArlPhayathaiA8 = 'ARL_A8';
  static const String kStationBtsSamrongE15 = 'BTS_E15';
  static const String kStationMrtSamrongYl23 = 'MRT_YL23';
  static const String kStationArlHuamakA4 = 'ARL_A4';
  static const String kStationMrtHuamakYl11 = 'MRT_YL11';
  static const String kStationMrtSilomBl26 = 'MRT_BL26';
  static const String kStationBtsSaladaengS2 = 'BTS_S2';
  static const String kStationMrtChatuchakBl13 = 'MRT_BL13';
  static const String kStationBtsMochitN8 = 'BTS_N8';
  static const String kStationMrtLatphraoBl15 = 'MRT_BL15';
  static const String kStationMrtLatphraoYl01 = 'MRT_YL01';

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
  static const double kPeakTransferWaitMinutes = 3.0;
  static const double kOffPeakTransferWaitMinutes = 5.0;

  // Graph Routing & Physical Constants
  static const double kDisruptedPenaltyWeight = 9999.0;
  static const int kDefaultDelayMinutes = 10;
  static const double kMetersPerDegreeLat = 111320.0;
  static const double kBangkokCosLat = 0.97;
  static const double kTrainSpeedMpm = 583.0;
  static const double kDwellTimeMinutes = 0.5;
  static const double kCandidateSearchRadiusMeters = 700.0;
  static const double kOverpassSearchRadiusMeters = 800.0;
  static const double kCrossPlatformThresholdMeters = 10.0;
  static const double kBaseTransferWaitMinutes = 2.0;
  static const double kOsrmDetourThresholdMeters = 150.0;
  static const double kOsrmMaxDetourMeters = 600.0;

  // ── Station-Specific Interchange Transfer Walk Times (minutes) ──
  // Estimated layout-based walk times per interchange pair, covering:
  //   - Cross-platform (same operator, no gate exit)
  //   - In-station transfer (same building, exit & re-enter gates)
  //   - Skywalk / connected building (walk between separate structures)
  //   - Separate building (walk to a different station building)
  //
  // Keys are sorted alphabetically: "STATION_A|STATION_B" where A < B.
  // The lookup helper `getInterchangeWalkMinutes` handles key ordering.
  static const Map<String, double> _interchangeWalkMinutes = {
    // ── Cross-platform transfers (same operator, no gate) ──
    // Siam: BTS Sukhumvit ↔ BTS Silom — walk across the platform
    'BTS_CEN|BTS_CEN_SILOM': 1.0,
    // Krung Thon Buri: BTS Silom ↔ BTS Gold — adjacent platform
    'BTS_G1|BTS_S7': 2.0,

    // ── Same-operator gate transfers ──
    // Tao Poon: MRT Blue ↔ MRT Purple — underground walkway, same operator
    'MRT_BL10|MRT_PP16': 3.0,
    // Lat Phrao: MRT Blue ↔ MRT Yellow — connected concourse
    'MRT_BL15|MRT_YL01': 3.0,
    // Nonthaburi Civic Center: MRT Pink ↔ MRT Purple — elevated walkway
    'MRT_PK01|MRT_PP11': 3.5,

    // ── Cross-operator transfers (exit gate → walk → enter gate) ──
    // Mo Chit / Chatuchak Park: BTS ↔ MRT — stairs down + short walk
    'BTS_N8|MRT_BL13': 4.0,
    // Ha Yaek Lat Phrao: BTS ↔ MRT — connected skywalk
    'BTS_N9|MRT_BL14': 4.0,
    // Sala Daeng / Si Lom: BTS ↔ MRT — stairs down to underground
    'BTS_S2|MRT_BL26': 4.0,
    // Asok / Sukhumvit: BTS ↔ MRT — exit BTS, skywalk, enter MRT
    'BTS_E4|MRT_BL22': 5.0,
    // Phaya Thai: BTS ↔ ARL — exit BTS, walk across building, enter ARL
    'ARL_A8|BTS_N2': 4.0,
    // Makkasan / Phetchaburi: ARL ↔ MRT — long covered walkway
    'ARL_A6|MRT_BL21': 5.0,
    // Samrong: BTS ↔ MRT Yellow — elevated walkway between platforms
    'BTS_E15|MRT_YL23': 4.0,
    // Hua Mak: ARL ↔ MRT Yellow — short walk between stations
    'ARL_A4|MRT_YL11': 4.0,
    // Bang Wa: MRT Blue ↔ BTS Silom — connected walkway
    'BTS_S12|MRT_BL34': 4.0,

    // ── Separate building / long-distance transfers ──
    // Bang Sue / Krung Thep Aphiwat: MRT Blue ↔ SRT Red — walk through
    // Grand Station building
    'MRT_BL11|SRT_RN00': 6.0,
    // Bang Son: MRT Purple ↔ SRT Red West — separate station buildings
    'MRT_PP15|SRT_RW01': 5.0,
    // Lak Si: MRT Pink ↔ SRT Red North — separate elevated/ground stations
    'MRT_PK14|SRT_RN05': 5.0,
  };

  /// Look up the estimated layout-based walk time (in minutes) for a specific
  /// interchange pair. Returns `null` if no station-specific override exists,
  /// allowing the caller to fall back to the generic distance-based formula.
  static double? getInterchangeWalkMinutes(
    String stationIdA,
    String stationIdB,
  ) {
    // Build a canonical key with IDs in alphabetical order
    final key = stationIdA.compareTo(stationIdB) < 0
        ? '$stationIdA|$stationIdB'
        : '$stationIdB|$stationIdA';
    return _interchangeWalkMinutes[key];
  }

  // GPS Passive Crowd Detection
  static const double kStationProximityMeters = 200.0;
  static const Duration kCrowdReportExpiry = Duration(minutes: 15);

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
  static const double kAvgTimeBetweenStations = 2.0;
  static const double kTransferWalkingTime =
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
