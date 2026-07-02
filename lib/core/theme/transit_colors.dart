import 'package:flutter/material.dart';

/// Transit line colors — official colors for each transit line
class TransitColors {
  TransitColors._();

  // BTS Sukhumvit Line — Green
  static const Color btsSukhumvit = Color(0xFF7DC242);
  static const Color btsSukhumvitDark = Color(0xFF5A9A2F);

  // BTS Silom Line — Dark Green
  static const Color btsSilom = Color(0xFF006838);
  static const Color btsSilomDark = Color(0xFF004D29);

  // BTS Gold Line — Gold
  static const Color btsGold = Color(0xFFC4A84E);
  static const Color btsGoldDark = Color(0xFFA08A3E);

  // MRT Blue Line — Blue
  static const Color mrtBlue = Color(0xFF1E3A8A);
  static const Color mrtBlueDark = Color(0xFF152C6B);

  // MRT Purple Line — Purple
  static const Color mrtPurple = Color(0xFF6B21A8);
  static const Color mrtPurpleDark = Color(0xFF531A85);

  // MRT Yellow Line — Yellow
  static const Color mrtYellow = Color(0xFFFBBF24);
  static const Color mrtYellowDark = Color(0xFFD4A017);

  // Airport Rail Link — Red/Maroon
  static const Color arl = Color(0xFFDC2626);
  static const Color arlDark = Color(0xFFB91C1C);

  // MRT Pink Line & Branch — Pink
  static const Color mrtPink = Color(0xFFE9008C);
  static const Color mrtPinkDark = Color(0xFFC00072);

  // SRT Red Lines — Red
  static const Color srtRedNorth = Color(0xFFCF142B);
  static const Color srtRedNorthDark = Color(0xFF9E0B1C);
  static const Color srtRedWest = Color(0xFFE2001A);
  static const Color srtRedWestDark = Color(0xFFB30012);

  /// Get color for a given line ID
  static Color getLineColor(String lineId) {
    switch (lineId) {
      case 'BTS_SUKHUMVIT':
        return btsSukhumvit;
      case 'BTS_SILOM':
        return btsSilom;
      case 'BTS_GOLD':
        return btsGold;
      case 'MRT_BLUE':
        return mrtBlue;
      case 'MRT_PURPLE':
        return mrtPurple;
      case 'MRT_YELLOW':
        return mrtYellow;
      case 'ARL':
        return arl;
      case 'MRT_PINK':
      case 'MRT_PINK_BRANCH':
        return mrtPink;
      case 'SRT_RED_NORTH':
        return srtRedNorth;
      case 'SRT_RED_WEST':
        return srtRedWest;
      default:
        return Colors.grey;
    }
  }

  /// Get darker variant for a given line ID
  static Color getLineDarkColor(String lineId) {
    switch (lineId) {
      case 'BTS_SUKHUMVIT':
        return btsSukhumvitDark;
      case 'BTS_SILOM':
        return btsSilomDark;
      case 'BTS_GOLD':
        return btsGoldDark;
      case 'MRT_BLUE':
        return mrtBlueDark;
      case 'MRT_PURPLE':
        return mrtPurpleDark;
      case 'MRT_YELLOW':
        return mrtYellowDark;
      case 'ARL':
        return arlDark;
      case 'MRT_PINK':
      case 'MRT_PINK_BRANCH':
        return mrtPinkDark;
      case 'SRT_RED_NORTH':
        return srtRedNorthDark;
      case 'SRT_RED_WEST':
        return srtRedWestDark;
      default:
        return Colors.grey.shade700;
    }
  }

  /// Get readable text color (white or dark slate) for a given line ID
  static Color getLineTextColor(String lineId) {
    if (lineId == 'MRT_YELLOW' || lineId == 'BTS_GOLD') {
      return const Color(0xFF1E293B); // Dark slate
    }
    return Colors.white;
  }
}
