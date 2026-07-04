import 'package:flutter/material.dart';
import 'src/app_theme_dark.dart';
import 'src/app_theme_light.dart';

export 'src/app_colors_extension.dart';

/// Central entrypoint for Bangkok Transit Planner's application themes.
class AppTheme {
  AppTheme._();

  static final ThemeData darkTheme = buildDarkTheme();
  static final ThemeData lightTheme = buildLightTheme();
}
