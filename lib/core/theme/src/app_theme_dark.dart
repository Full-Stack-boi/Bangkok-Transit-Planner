import 'package:flutter/material.dart';
import 'app_colors_extension.dart';
import 'app_theme_shared.dart';

/// Dark theme builder using shared components decorators
ThemeData buildDarkTheme() {
  const Color primaryDark = Color(0xFF77B0AA);   // Dusty Sage/Teal
  const Color surfaceDark = Color(0xFF11141A);    // Comforting Slate Navy
  const Color cardDark = Color(0xFF1A1F2B);       // Slate Navy Card
  const Color outlineDark = Color(0xFF252D3D);     // Slate Navy Outline Border

  const scheme = ColorScheme.dark(
    primary: primaryDark,
    onPrimary: Colors.white,
    secondary: Color(0xFF2DD4BF), // Soft Mint Teal
    onSecondary: Colors.black,
    surface: surfaceDark,
    onSurface: Color(0xFFECF0F6), // Soft Cool White
    error: Color(0xFFEF4444),
    onError: Colors.white,
    outline: outlineDark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: surfaceDark,
    cardColor: cardDark,
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension.dark,
    ],
    appBarTheme: buildSharedAppBarTheme(scheme),
    navigationBarTheme: buildSharedNavigationBarTheme(scheme, cardDark),
    cardTheme: buildSharedCardTheme(
      scheme,
      color: cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: outlineDark, width: 1),
      ),
    ),
    inputDecorationTheme: buildSharedInputDecorationTheme(
      scheme,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineDark),
      ),
    ),
    elevatedButtonTheme: buildSharedElevatedButtonTheme(scheme, isDark: true),
    outlinedButtonTheme: buildSharedOutlinedButtonTheme(
      scheme,
      borderSide: const BorderSide(color: outlineDark),
    ),
    bottomSheetTheme: buildSharedBottomSheetTheme(scheme, cardDark),
    textTheme: buildSharedTextTheme(scheme, ThemeData.dark().textTheme).copyWith(
      titleMedium: const TextStyle(color: Color(0xFFE2E8F0)),
      bodyLarge: const TextStyle(color: Color(0xFFE2E8F0)),
      bodyMedium: const TextStyle(color: Color(0xFF94A3B8)),
    ),
  );
}
