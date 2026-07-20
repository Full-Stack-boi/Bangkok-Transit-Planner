/// Core app colors
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Navigation Rail ───
  /// Lavender accent for the Route tab (BTS Sukhumvit line inspired)
  static const Color kSoftLavender = Color(0xFF818CF8);
  /// Coral pink accent for the Favorites tab
  static const Color kCoralPink = Color(0xFFF472B6);
  /// Warm amber accent for the Utility tab
  static const Color kWarmAmber = Color(0xFFF59E0B);
  /// Color for unselected nav items in both light and dark modes
  static const Color kUnselectedNavColor = Color(0xFF64748B);

  // ─── Map Pins ───
  /// Color for origin/departure pin and icon
  static const Color kOriginPinColor = Colors.green;
  /// Color for destination/arrival pin and icon
  static const Color kDestinationPinColor = Colors.red;

  // ─── Semantic / Status ───
  static const Color kSuccessColor = Colors.green;
  static const Color kErrorColor = Colors.red;
  static const Color kWarningColor = Color(0xFFF59E0B); // amber

  // ─── Crowd Level ───
  static const Color kCrowdHigh = Colors.red;
  static const Color kCrowdHighLight = Color(0xFFEF5350); // red.shade400
  static const Color kCrowdMedium = Colors.orange;
  static const Color kCrowdMediumLight = Color(0xFFFFA726); // orange.shade400
  static const Color kCrowdLow = Colors.green;
  static const Color kCrowdLowLight = Color(0xFF66BB6A); // green.shade400

  // ─── Transit Status ───
  /// Color used for 'train arriving soon' indicator
  static const Color kTrainArrivingColor = Color(0xFFF59E0B); // amber.shade700
  /// Color for fare discount labels
  static const Color kDiscountColor = Color(0xFF43A047); // green.shade600
  /// Color for exit gate badge on transfer instructions
  static const Color kExitBadgeColor = Color(0xFFEF6C00); // orange.shade800

  // ─── Google Sign-In Brand Colors ───
  static const Color kGoogleButtonDark = Color(0xFF131314);
  static const Color kGoogleButtonDarkText = Color(0xFFE3E3E3);
  static const Color kGoogleButtonLightText = Color(0xFF1F1F1F);
  static const Color kGoogleButtonDarkBorder = Color(0xFF333537);
  static const Color kGoogleButtonLightBorder = Color(0xFF747775);

  // ─── Transit Card Gradients (utility_screen.dart) ───
  static const Color kBtsGradientStart = Color(0xFF66BB6A); // green.shade400
  static const Color kBtsGradientEnd = Color(0xFF388E3C);   // green.shade700
  static const Color kMrtGradientStart = Color(0xFF42A5F5); // blue.shade400
  static const Color kMrtGradientEnd = Color(0xFF1565C0);   // blue.shade800
  static const Color kArlGradientStart = Color(0xFFEF5350); // red.shade400
  static const Color kArlGradientEnd = Color(0xFFC62828);   // red.shade700
  static const Color kSrtGradientStart = Color(0xFFC62828); // red.shade800
  static const Color kSrtGradientEnd = Color(0xFFB71C1C);   // red.shade900

  // ─── Miscellaneous ───
  /// Dark slate used as text color on dark-mode station markers
  static const Color kDarkSlateText = Color(0xFF1E293B);
  /// Fallback color for unknown transit lines
  static const Color kUnknownLineColor = Colors.grey;
  /// Bus stop / Namtang transit color (green)
  static const Color kBusTransitColor = Colors.green;
  /// Boat stop color
  static const Color kBoatTransitColor = Color(0xFF1565C0); // blue.shade700
  /// Commuter train color
  static const Color kCommuterTrainColor = Color(0xFFC62828); // red.shade700
  /// Warning banner background (amber with opacity)
  static const Color kWarningBannerBg = Color(0x1AF59E0B); // amber 10%
  static const Color kWarningBannerBorder = Color(0x66F59E0B); // amber 40%
  static const Color kWarningBannerIcon = Color(0xFFEF6C00); // amber.800
}
