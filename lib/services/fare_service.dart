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

  /// Calculate fare for a single line segment
  int calculateFare(String lineId, int stationCount) {
    final table = _getFareTable(lineId);
    if (table == null) return 0;

    final index = stationCount.clamp(0, table.length - 1);
    return table[index];
  }

  /// Calculate total fare for a multi-line route
  /// Each line segment is calculated separately and summed
  int calculateTotalFare(List<FareSegment> segments) {
    int total = 0;
    for (final segment in segments) {
      total += calculateFare(segment.lineId, segment.stationCount);
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
