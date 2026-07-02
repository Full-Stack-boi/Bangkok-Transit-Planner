/// Fare calculation service with real fare tables
/// NOTE: Fares are hardcoded based on 2025/2026 rates
/// Stored here for easy updates — consider moving to assets/data/fares.json
class FareService {
  // ─── BTS Fare Table (Zone-based) ───
  // Number of stations traveled → fare in THB
  static const List<int> _btsFareTable = [
    17,  // 0 stations (same station, minimum fare)
    17,  // 1 station
    25,  // 2 stations
    28,  // 3 stations
    32,  // 4 stations
    37,  // 5 stations
    42,  // 6 stations
    47,  // 7 stations
    52,  // 8 stations
    57,  // 9 stations
    62,  // 10+ stations
  ];

  // ─── MRT Blue Line Fare Table ───
  static const List<int> _mrtBlueFareTable = [
    17,  // 0 stations
    17,  // 1 station
    21,  // 2 stations
    25,  // 3 stations
    28,  // 4 stations
    30,  // 5 stations
    32,  // 6 stations
    35,  // 7 stations
    37,  // 8 stations
    40,  // 9 stations
    42,  // 10+ stations
  ];

  // ─── MRT Purple Line Fare Table ───
  static const List<int> _mrtPurpleFareTable = [
    14,  // 0 stations
    17,  // 1 station
    20,  // 2 stations
    23,  // 3 stations
    25,  // 4 stations
    27,  // 5 stations
    30,  // 6 stations
    33,  // 7 stations
    36,  // 8 stations
    39,  // 9 stations
    42,  // 10+ stations
  ];

  // ─── MRT Yellow Line Fare Table ───
  static const List<int> _mrtYellowFareTable = [
    15,  // 0 stations
    15,  // 1 station
    20,  // 2 stations
    25,  // 3 stations
    28,  // 4 stations
    30,  // 5 stations
    33,  // 6 stations
    35,  // 7 stations
    38,  // 8 stations
    40,  // 9 stations
    45,  // 10+ stations
  ];

  // ─── MRT Pink Line Fare Table ───
  static const List<int> _mrtPinkFareTable = [
    15,  // 0 stations
    15,  // 1 station
    20,  // 2 stations
    25,  // 3 stations
    28,  // 4 stations
    30,  // 5 stations
    33,  // 6 stations
    35,  // 7 stations
    38,  // 8 stations
    40,  // 9 stations
    45,  // 10+ stations
  ];

  // ─── SRT Red Line Fare Table ───
  static const List<int> _srtRedFareTable = [
    12,  // 0 stations
    16,  // 1 station
    20,  // 2 stations
    24,  // 3 stations
    28,  // 4 stations
    32,  // 5 stations
    36,  // 6 stations
    40,  // 7 stations
    42,  // 8+ stations
  ];

  // ─── Airport Rail Link (ARL) Fare Table ───
  // Fixed fare by station pair (simplified: by number of stops)
  static const List<int> _arlFareTable = [
    15,  // 0 stops
    15,  // 1 stop
    20,  // 2 stops
    25,  // 3 stops
    30,  // 4 stops
    35,  // 5 stops
    40,  // 6 stops
    45,  // 7 stops (full line Phaya Thai - Suvarnabhumi)
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
        return (standardFare * 0.9).round(); // 10% Student discount for app utility
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
    return total;
  }

  List<int>? _getFareTable(String lineId) {
    switch (lineId) {
      case 'BTS_SUKHUMVIT':
      case 'BTS_SILOM':
      case 'BTS_GOLD':
        return _btsFareTable;
      case 'MRT_BLUE':
        return _mrtBlueFareTable;
      case 'MRT_PURPLE':
        return _mrtPurpleFareTable;
      case 'MRT_YELLOW':
        return _mrtYellowFareTable;
      case 'MRT_PINK':
      case 'MRT_PINK_BRANCH':
        return _mrtPinkFareTable;
      case 'SRT_RED_NORTH':
      case 'SRT_RED_WEST':
        return _srtRedFareTable;
      case 'ARL':
        return _arlFareTable;
      default:
        return null;
    }
  }

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

  const FareSegment({
    required this.lineId,
    required this.stationCount,
  });
}
