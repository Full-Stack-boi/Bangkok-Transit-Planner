library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Navigation
  static const Color kSoftLavender = Color(0xFF818CF8);
  static const Color kCoralPink = Color(0xFFF472B6);
  static const Color kWarmAmber = Color(0xFFF59E0B);
  static const Color kUnselectedNavColor = Color(0xFF64748B);

  // Map Pins
  static const Color kOriginPinColor = Colors.green;
  static const Color kDestinationPinColor = Colors.red;

  // Semantic / Status
  static const Color kSuccessColor = Colors.green;
  static const Color kErrorColor = Colors.red;
  static const Color kWarningColor = Color(0xFFF59E0B);

  // Crowd Level
  static const Color kCrowdHigh = Colors.red;
  static const Color kCrowdHighLight = Color(0xFFEF5350);
  static const Color kCrowdMedium = Colors.orange;
  static const Color kCrowdMediumLight = Color(0xFFFFA726);
  static const Color kCrowdLow = Colors.green;
  static const Color kCrowdLowLight = Color(0xFF66BB6A);

  // Transit Status
  static const Color kTrainArrivingColor = Color(0xFFF59E0B);
  static const Color kDiscountColor = Color(0xFF43A047);
  static const Color kExitBadgeColor = Color(0xFFEF6C00);

  // Google Sign-In Brand Colors
  static const Color kGoogleButtonDark = Color(0xFF131314);
  static const Color kGoogleButtonDarkText = Color(0xFFE3E3E3);
  static const Color kGoogleButtonLightText = Color(0xFF1F1F1F);
  static const Color kGoogleButtonDarkBorder = Color(0xFF333537);
  static const Color kGoogleButtonLightBorder = Color(0xFF747775);

  // Transit Card Gradients
  static const Color kBtsGradientStart = Color(0xFF66BB6A);
  static const Color kBtsGradientEnd = Color(0xFF388E3C);
  static const Color kMrtGradientStart = Color(0xFF42A5F5);
  static const Color kMrtGradientEnd = Color(0xFF1565C0);
  static const Color kArlGradientStart = Color(0xFFEF5350);
  static const Color kArlGradientEnd = Color(0xFFC62828);
  static const Color kSrtGradientStart = Color(0xFFC62828);
  static const Color kSrtGradientEnd = Color(0xFFB71C1C);

  // Miscellaneous
  static const Color kDarkSlateText = Color(0xFF1E293B);
  static const Color kUnknownLineColor = Colors.grey;
  static const Color kBusTransitColor = Colors.green;
  static const Color kBoatTransitColor = Color(0xFF1565C0);
  static const Color kCommuterTrainColor = Color(0xFFC62828);
  static const Color kWarningBannerBg = Color(0x1AF59E0B);
  static const Color kWarningBannerBorder = Color(0x66F59E0B);
  static const Color kWarningBannerIcon = Color(0xFFEF6C00);
}
