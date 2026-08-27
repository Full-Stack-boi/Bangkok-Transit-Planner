import '../models/transit_enums.dart';

class FareService {
  // BTS Fare Table (Zone-based)
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
    62, // 10 stations
    65, // 11+ stations (concession + extension cap)
  ];

  // BTS Gold Line Flat Fare
  static const List<int> _btsGoldFareTable = [
    16, // 0 stations
    16, // 1 station
    16, // 2+ stations
  ];

  // MRT Blue Line Fare Table (17-44 THB)
  static const List<int> _mrtBlueFareTable = [
    17, // 0 stations
    17, // 1 station
    20, // 2 stations
    22, // 3 stations
    25, // 4 stations
    27, // 5 stations
    29, // 6 stations
    32, // 7 stations
    34, // 8 stations
    37, // 9 stations
    39, // 10 stations
    42, // 11 stations
    44, // 12+ stations
  ];

  // MRT Purple Line Fare Table (14-42 THB)
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

  // MRT Yellow Line Fare Table (EBM Monorail, 15-45 THB)
  static const List<int> _mrtYellowFareTable = [
    15, // 0 stations
    19, // 1 station
    23, // 2 stations
    27, // 3 stations
    30, // 4 stations
    33, // 5 stations
    36, // 6 stations
    39, // 7 stations
    42, // 8 stations
    45, // 9+ stations
  ];

  // MRT Pink Line Fare Table (NBM Monorail, 15-45 THB)
  static const List<int> _mrtPinkFareTable = [
    15, // 0 stations
    19, // 1 station
    23, // 2 stations
    27, // 3 stations
    30, // 4 stations
    33, // 5 stations
    36, // 6 stations
    39, // 7 stations
    42, // 8 stations
    45, // 9+ stations
  ];

  // SRT Red Line Fare Table (12-42 THB)
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
    TransitCardType btsCardType = TransitCardType.standard,
    TransitCardType mrtCardType = TransitCardType.standard,
    TransitCardType arlCardType = TransitCardType.standard,
    TransitCardType srtCardType = TransitCardType.standard,
  }) {
    final table = _getFareTable(lineId);
    if (table == null) return 0;

    final index = stationCount.clamp(0, table.length - 1);
    final standardFare = table[index];

    final network = TransitNetwork.fromLineId(lineId);
    if (network == null) return standardFare;

    switch (network) {
      case TransitNetwork.bts:
        if (btsCardType == TransitCardType.senior) {
          return (standardFare * 0.5).round(); // 50% Senior discount
        } else if (btsCardType == TransitCardType.tripPackage) {
          // BTS Trip Package flat rate only applies to BTS Sukhumvit/Silom main concession lines
          if (lineId.startsWith('BTS_SUKHUMVIT') || lineId.startsWith('BTS_SILOM')) {
            return standardFare < 30 ? standardFare : 30;
          }
          return standardFare;
        } else if (btsCardType == TransitCardType.student) {
          return (standardFare * 0.9).round(); // 10% Student discount
        }
        break;
      case TransitNetwork.mrt:
        if (mrtCardType == TransitCardType.student) {
          return (standardFare * 0.9).round(); // 10% Student discount
        } else if (mrtCardType == TransitCardType.senior) {
          return (standardFare * 0.5).round(); // 50% Senior discount
        }
        break;
      case TransitNetwork.arl:
        if (arlCardType == TransitCardType.student) {
          return (standardFare * 0.8).round(); // 20% Student discount
        } else if (arlCardType == TransitCardType.senior) {
          return (standardFare * 0.5).round(); // 50% Senior discount
        }
        break;
      case TransitNetwork.srt:
        if (srtCardType == TransitCardType.student) {
          return (standardFare * 0.9).round(); // 10% Student discount
        } else if (srtCardType == TransitCardType.senior) {
          return (standardFare * 0.5).round(); // 50% Senior discount
        }
        break;
    }

    return standardFare;
  }

  /// Calculate total fare for a multi-line route taking card types and discounts into account
  int calculateTotalFare(
    List<FareSegment> segments, {
    TransitCardType btsCardType = TransitCardType.standard,
    TransitCardType mrtCardType = TransitCardType.standard,
    TransitCardType arlCardType = TransitCardType.standard,
    TransitCardType srtCardType = TransitCardType.standard,
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

        final network2 = TransitNetwork.fromLineId(s2.lineId);
        if (network2 != null) {
          switch (network2) {
            case TransitNetwork.bts:
              if (btsCardType == TransitCardType.student) {
                discountedWaiver = (entryFee * 0.9).round();
              } else if (btsCardType == TransitCardType.senior) {
                discountedWaiver = (entryFee * 0.5).round();
              }
              break;
            case TransitNetwork.mrt:
              if (mrtCardType == TransitCardType.student) {
                discountedWaiver = (entryFee * 0.9).round();
              } else if (mrtCardType == TransitCardType.senior) {
                discountedWaiver = (entryFee * 0.5).round();
              }
              break;
            case TransitNetwork.srt:
              if (srtCardType == TransitCardType.student) {
                discountedWaiver = (entryFee * 0.9).round();
              } else if (srtCardType == TransitCardType.senior) {
                discountedWaiver = (entryFee * 0.5).round();
              }
              break;
            case TransitNetwork.arl:
              break;
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
    if (lineId == 'BTS_GOLD') return 16;
    if (lineId == 'MRT_BLUE') return 17;
    if (lineId == 'MRT_PURPLE') return 14;
    if (lineId == 'MRT_YELLOW') return 15;
    if (lineId == 'MRT_PINK' || lineId == 'MRT_PINK_BRANCH') return 15;
    if (lineId.startsWith('SRT')) return 12;
    if (lineId == 'ARL') return 15;
    return 0;
  }

  bool _qualifiesForTransferWaiver(String line1, String line2) {
    // Explicit connected physical interchange transfer pairs qualifying for MRTA EMV fee waiver
    const waiverPairs = {
      {'MRT_BLUE', 'MRT_PURPLE'}, // Tao Poon Interchange
      {'MRT_BLUE', 'MRT_YELLOW'}, // Lat Phrao Interchange
      {'MRT_PINK', 'MRT_PURPLE'}, // Nonthaburi Civic Center Interchange
      {'MRT_PINK_BRANCH', 'MRT_PURPLE'}, // Nonthaburi Civic Center via branch
      {'MRT_BLUE', 'SRT_RED_NORTH'}, // Bang Sue Grand Station
      {'MRT_BLUE', 'SRT_RED_WEST'}, // Bang Sue Grand Station
      {'MRT_PURPLE', 'SRT_RED_WEST'}, // Bang Son Interchange
      {'MRT_PINK', 'SRT_RED_NORTH'}, // Lak Si Interchange
    };

    return waiverPairs.any((pair) => pair.contains(line1) && pair.contains(line2));
  }

  /// Static lookup map for O(1) fare table access (replaces switch-case)
  static final Map<String, List<int>> _fareTableMap = {
    'BTS_SUKHUMVIT': _btsFareTable,
    'BTS_SILOM': _btsFareTable,
    'BTS_GOLD': _btsGoldFareTable,
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

  /// Date when fare matrices were last audited and verified
  static const String lastUpdated = '2026-08-28';

  /// Official effective dates per rail line
  static const Map<String, String> _lineUpdatedDates = {
    'BTS_SUKHUMVIT': '2025-11-01',
    'BTS_SILOM': '2025-11-01',
    'BTS_GOLD': '2025-11-01',
    'MRT_BLUE': '2026-07-03',
    'MRT_PURPLE': '2025-12-01',
    'MRT_YELLOW': '2025-01-01',
    'MRT_PINK': '2026-07-03',
    'MRT_PINK_BRANCH': '2026-07-03',
    'SRT_RED_NORTH': '2025-12-01',
    'SRT_RED_WEST': '2025-12-01',
    'ARL': '2025-01-01',
  };

  /// Get official effective date for a specific line
  String getLineLastUpdated(String lineId) {
    return _lineUpdatedDates[lineId] ?? lastUpdated;
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

  const FareSegment({required this.lineId, required this.stationCount});
}
