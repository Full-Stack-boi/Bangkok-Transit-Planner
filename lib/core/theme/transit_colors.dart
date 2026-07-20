import 'package:flutter/material.dart';
import '../constants/transit_constants.dart';

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
      case TransitConstants.kBtsSukhumvit:
        return btsSukhumvit;
      case TransitConstants.kBtsSilom:
        return btsSilom;
      case TransitConstants.kBtsGold:
        return btsGold;
      case TransitConstants.kMrtBlue:
        return mrtBlue;
      case TransitConstants.kMrtPurple:
        return mrtPurple;
      case TransitConstants.kMrtYellow:
        return mrtYellow;
      case TransitConstants.kArl:
        return arl;
      case TransitConstants.kMrtPink:
      case TransitConstants.kMrtPinkBranch:
        return mrtPink;
      case TransitConstants.kSrtRedNorth:
        return srtRedNorth;
      case TransitConstants.kSrtRedWest:
        return srtRedWest;
      default:
        return Colors.grey;
    }
  }

  /// Get darker variant for a given line ID
  static Color getLineDarkColor(String lineId) {
    switch (lineId) {
      case TransitConstants.kBtsSukhumvit:
        return btsSukhumvitDark;
      case TransitConstants.kBtsSilom:
        return btsSilomDark;
      case TransitConstants.kBtsGold:
        return btsGoldDark;
      case TransitConstants.kMrtBlue:
        return mrtBlueDark;
      case TransitConstants.kMrtPurple:
        return mrtPurpleDark;
      case TransitConstants.kMrtYellow:
        return mrtYellowDark;
      case TransitConstants.kArl:
        return arlDark;
      case TransitConstants.kMrtPink:
      case TransitConstants.kMrtPinkBranch:
        return mrtPinkDark;
      case TransitConstants.kSrtRedNorth:
        return srtRedNorthDark;
      case TransitConstants.kSrtRedWest:
        return srtRedWestDark;
      default:
        return Colors.grey.shade700;
    }
  }

  /// Get readable text color (white or dark slate) for a given line ID
  static Color getLineTextColor(String lineId) {
    if (lineId == TransitConstants.kMrtYellow ||
        lineId == TransitConstants.kBtsGold) {
      return const Color(0xFF1E293B); // Dark slate
    }
    return Colors.white;
  }
}
