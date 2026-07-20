import 'package:flutter/material.dart';

/// Custom theme extension for centralizing app colors to ensure consistency
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color? timeColor;
  final Color? moneyColor;
  final Color? routeColor;
  final Color? favoriteColor;
  final Color? landmarkColor;
  final Color? gpsPinColor;

  const AppColorsExtension({
    required this.timeColor,
    required this.moneyColor,
    required this.routeColor,
    required this.favoriteColor,
    required this.landmarkColor,
    required this.gpsPinColor,
  });

  /// Dark theme palette constant
  static const AppColorsExtension dark = AppColorsExtension(
    timeColor: Color(0xFFFCD34D), // Colors.amber.shade300
    moneyColor: Color(0xFF2DD4BF), // Soft Green/Teal
    routeColor: Color(0xFF818CF8), // Soft Lavender
    favoriteColor: Color(0xFFF472B6), // Coral Pink
    landmarkColor: Color(0xFFF97316), // Warm Coral Orange
    gpsPinColor: Color(0xFF2DD4BF), // Soft Teal
  );

  /// Light theme palette constant
  static const AppColorsExtension light = AppColorsExtension(
    timeColor: Color(0xFFD97706), // Warm Dark Amber/Gold
    moneyColor: Color(0xFF0D9488), // Teal Green
    routeColor: Color(0xFF4F46E5), // Indigo
    favoriteColor: Color(0xFFDB2777), // Deep Pink
    landmarkColor: Color(0xFFEA580C), // Dark Orange
    gpsPinColor: Color(0xFF0D9488), // Teal
  );

  @override
  AppColorsExtension copyWith({
    Color? timeColor,
    Color? moneyColor,
    Color? routeColor,
    Color? favoriteColor,
    Color? landmarkColor,
    Color? gpsPinColor,
  }) {
    return AppColorsExtension(
      timeColor: timeColor ?? this.timeColor,
      moneyColor: moneyColor ?? this.moneyColor,
      routeColor: routeColor ?? this.routeColor,
      favoriteColor: favoriteColor ?? this.favoriteColor,
      landmarkColor: landmarkColor ?? this.landmarkColor,
      gpsPinColor: gpsPinColor ?? this.gpsPinColor,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      timeColor: Color.lerp(timeColor, other.timeColor, t),
      moneyColor: Color.lerp(moneyColor, other.moneyColor, t),
      routeColor: Color.lerp(routeColor, other.routeColor, t),
      favoriteColor: Color.lerp(favoriteColor, other.favoriteColor, t),
      landmarkColor: Color.lerp(landmarkColor, other.landmarkColor, t),
      gpsPinColor: Color.lerp(gpsPinColor, other.gpsPinColor, t),
    );
  }
}

/// Extension helper on [ThemeData] to fetch custom app colors easily
extension AppThemeData on ThemeData {
  AppColorsExtension get appColors => extension<AppColorsExtension>()!;
}
