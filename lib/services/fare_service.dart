/// Fare calculation service with real fare tables
/// NOTE: Fares are hardcoded based on 2025/2026 rates
/// Stored here for easy updates — consider moving to assets/data/fares.json
class FareService {
  // BTS Fare Table (Zone-based)
  // Number of stations traveled → fare in THB
  static const List<int> _btsFareTable = [
    17, // 0 stations (same station, minimum fare)
    17, // 1 station
    25, // 2 stations
    28, // 3 stations
    32, // 4 stations
    37, // 5 stations
    42, // 6 stations
    47, // 7 stations
    52, // 8 stations
    57, // 9 stations
    62, // 10+ stations
  ];

  // MRT Blue Line Fare Table
  static const List<int> _mrtBlueFareTable = [
    17, // 0 stations
    17, // 1 station
    21, // 2 stations
    25, // 3 stations
    28, // 4 stations
    30, // 5 stations
    32, // 6 stations
    35, // 7 stations
    37, // 8 stations
    40, // 9 stations
    42, // 10+ stations
  ];

  // MRT Purple Line Fare Table
  static const List<int> _mrtPurpleFareTable = [
    14, // 0 stations
    17, // 1 station
    20, // 2 stations
    23, // 3 stations
    25, // 4 stations
    27, // 5 stations
    30, // 6 stations
    33, // 7 stations
    36, // 8 stations
    39, // 9 stations
    42, // 10+ stations
  ];

  // MRT Yellow Line Fare Table
  static const List<int> _mrtYellowFareTable = [
    15, // 0 stations
    15, // 1 station
    20, // 2 stations
    25, // 3 stations
    28, // 4 stations
    30, // 5 stations
    33, // 6 stations
    35, // 7 stations
    38, // 8 stations
    40, // 9 stations
    45, // 10+ stations
  ];

  // MRT Pink Line Fare Table
  static const List<int> _mrtPinkFareTable = [
    15, // 0 stations
    15, // 1 station
    20, // 2 stations
    25, // 3 stations
    28, // 4 stations
    30, // 5 stations
    33, // 6 stations
    35, // 7 stations
    38, // 8 stations
    40, // 9 stations
    45, // 10+ stations
  ];

  // SRT Red Line Fare Table
  static const List<int> _srtRedFareTable = [
    12, // 0 stations
    16, // 1 station
    20, // 2 stations
    24, // 3 stations
    28, // 4 stations
    32, // 5 stations
    36, // 6 stations
    40, // 7 stations
    42, // 8+ stations
  ];

  // Airport Rail Link (ARL) Fare Table
  // Fixed fare by station pair (simplified: by number of stops)
  static const List<int> _arlFareTable = [
    15, // 0 stops
    15, // 1 stop
    20, // 2 stops
    25, // 3 stops
    30, // 4 stops
    35, // 5 stops
    40, // 6 stops
    45, // 7 stops (full line Phaya Thai - Suvarnabhumi)
  ];

  /// Calculate fare for a single line segment taking card types and discounts into account
  int calculateFare(
    String lineId,
    int stationCount, {
    String btsCardType = 'standard',
    String mrtCardType = 'standard',
    String arlCardType = 'standard',
    String srtCardType = 'standard',
  }) {
    final table = _getFareTable(lineId);
    if (table == null) return 0;

    final index = stationCount.clamp(0, table.length - 1);
    final standardFare = table[index];

    // Determine network type
    final isBts = lineId.startsWith('BTS');
    final isMrt = lineId.startsWith('MRT');
    final isArl = lineId == 'ARL';
    final isSrt = lineId.startsWith('SRT');

    if (isBts) {
      if (btsCardType == 'senior') {
        return (standardFare * 0.5).round(); // 50% Senior discount
      } else if (btsCardType == 'trip_package') {
        // BTS Trip Package flat rate (usually ~28-30 THB per trip). If standard fare is cheaper, pay standard.
        return standardFare < 30 ? standardFare : 30;
      } else if (btsCardType == 'student') {
        return (standardFare * 0.9)
            .round(); // 10% Student discount for app utility
      }
    } else if (isMrt) {
      if (mrtCardType == 'student') {
        return (standardFare * 0.9).round(); // 10% Student discount
      } else if (mrtCardType == 'senior') {
        return (standardFare * 0.5).round(); // 50% Senior discount
      }
    } else if (isArl) {
      if (arlCardType == 'student') {
        return (standardFare * 0.8).round(); // 20% Student discount
      } else if (arlCardType == 'senior') {
        return (standardFare * 0.5).round(); // 50% Senior discount
      }
    } else if (isSrt) {
      if (srtCardType == 'student') {
        return (standardFare * 0.9).round(); // 10% Student discount
      } else if (srtCardType == 'senior') {
        return (standardFare * 0.5).round(); // 50% Senior discount
      }
    }

    return standardFare;
  }

  /// Calculate total fare for a multi-line route taking card types and discounts into account
  int calculateTotalFare(
    List<FareSegment> segments, {
    String btsCardType = 'standard',
    String mrtCardType = 'standard',
    String arlCardType = 'standard',
    String srtCardType = 'standard',
  }) {
    int total = 0;

    // Calculate standard fares for each segment
    for (final segment in segments) {
      total += calculateFare(
        segment.lineId,
        segment.stationCount,
        btsCardType: btsCardType,
        mrtCardType: mrtCardType,
        arlCardType: arlCardType,
        srtCardType: srtCardType,
      );
    }

    // Apply transfer promotions and waive entry fees for adjacent rail segments
    final railIndices = <int>[];
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].lineId != 'WALK') {
        railIndices.add(i);
      }
    }

    for (int k = 0; k < railIndices.length - 1; k++) {
      final i1 = railIndices[k];
      final i2 = railIndices[k + 1];
      final s1 = segments[i1];
      final s2 = segments[i2];

      if (_qualifiesForTransferWaiver(s1.lineId, s2.lineId)) {
        final entryFee = _getEntryFee(s2.lineId);
        int discountedWaiver = entryFee;

        final isMrt2 = s2.lineId.startsWith('MRT');
        final isSrt2 = s2.lineId.startsWith('SRT');

        if (isMrt2) {
          if (mrtCardType == 'student') {
            discountedWaiver = (entryFee * 0.9).round();
          } else if (mrtCardType == 'senior') {
            discountedWaiver = (entryFee * 0.5).round();
          }
        } else if (isSrt2) {
          if (srtCardType == 'student') {
            discountedWaiver = (entryFee * 0.9).round();
          } else if (srtCardType == 'senior') {
            discountedWaiver = (entryFee * 0.5).round();
          }
        }

        total -= discountedWaiver;
      }
    }

    // Ensure total fare never drops below minimum possible fare (0 THB)
    return total < 0 ? 0 : total;
  }

  int _getEntryFee(String lineId) {
    if (lineId.startsWith('BTS_SUKHUMVIT') || lineId.startsWith('BTS_SILOM')) {
      return 17;
    }
    if (lineId == 'BTS_GOLD') return 15;
    if (lineId == 'MRT_BLUE') return 17;
    if (lineId == 'MRT_PURPLE') return 14;
    if (lineId == 'MRT_YELLOW') return 15;
    if (lineId == 'MRT_PINK' || lineId == 'MRT_PINK_BRANCH') return 15;
    if (lineId.startsWith('SRT')) return 12;
    if (lineId == 'ARL') return 15;
    return 0;
  }

  bool _qualifiesForTransferWaiver(String line1, String line2) {
    final isMrt1 = line1.startsWith('MRT');
    final isMrt2 = line2.startsWith('MRT');
    final isSrt1 = line1.startsWith('SRT');
    final isSrt2 = line2.startsWith('SRT');

    // MRT <-> MRT (Blue, Purple, Yellow, Pink)
    if (isMrt1 && isMrt2) return true;
    // MRT <-> SRT Red
    if ((isMrt1 && isSrt2) || (isSrt1 && isMrt2)) return true;

    return false;
  }

  /// Static lookup map for O(1) fare table access (replaces switch-case)
  static final Map<String, List<int>> _fareTableMap = {
    'BTS_SUKHUMVIT': _btsFareTable,
    'BTS_SILOM': _btsFareTable,
    'BTS_GOLD': _btsFareTable,
    'MRT_BLUE': _mrtBlueFareTable,
    'MRT_PURPLE': _mrtPurpleFareTable,
    'MRT_YELLOW': _mrtYellowFareTable,
    'MRT_PINK': _mrtPinkFareTable,
    'MRT_PINK_BRANCH': _mrtPinkFareTable,
    'SRT_RED_NORTH': _srtRedFareTable,
    'SRT_RED_WEST': _srtRedFareTable,
    'ARL': _arlFareTable,
  };

  List<int>? _getFareTable(String lineId) => _fareTableMap[lineId];

  /// Get fare range text for a line
  String getFareRangeText(String lineId) {
    final table = _getFareTable(lineId);
    if (table == null || table.isEmpty) return 'ไม่มีข้อมูล';
    return '${table.first} - ${table.last} บาท';
  }
}

/// A segment for fare calculation
class FareSegment {
  final String lineId;
  final int stationCount;

  const FareSegment({required this.lineId, required this.stationCount});
}
