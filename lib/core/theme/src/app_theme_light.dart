import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors_extension.dart';
import 'app_theme_shared.dart';

/// Light theme builder using shared components decorators
ThemeData buildLightTheme() {
  const Color primaryLight = Color(0xFF4F46E5);
  const Color surfaceLight = Color(0xFFF8FAFC);   // Slate 50
  const Color cardLight = Color(0xFFFFFFFF);
  const Color outlineLight = Color(0xFFCBD5E1);

  const scheme = ColorScheme.light(
    primary: primaryLight,
    onPrimary: Colors.white,
    secondary: Color(0xFF0891B2), // Cyan 600
    onSecondary: Colors.white,
    surface: surfaceLight,
    onSurface: Color(0xFF1E293B), // Slate 800
    error: Color(0xFFDC2626),
    onError: Colors.white,
    outline: outlineLight,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: surfaceLight,
    cardColor: cardLight,
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension.light,
    ],
    appBarTheme: buildSharedAppBarTheme(scheme),
    navigationBarTheme: buildSharedNavigationBarTheme(scheme, cardLight).copyWith(
      indicatorColor: primaryLight.withValues(alpha: 0.1),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryLight, size: 24);
        }
        return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.outfit(
            color: primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return GoogleFonts.outfit(
          color: const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    cardTheme: buildSharedCardTheme(
      scheme,
      color: cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    inputDecorationTheme: buildSharedInputDecorationTheme(
      scheme,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineLight),
      ),
    ),
    elevatedButtonTheme: buildSharedElevatedButtonTheme(scheme, isDark: false),
    outlinedButtonTheme: buildSharedOutlinedButtonTheme(
      scheme,
      borderSide: const BorderSide(color: outlineLight),
      textColor: const Color(0xFF1E293B),
    ),
    bottomSheetTheme: buildSharedBottomSheetTheme(scheme, cardLight),
    textTheme: buildSharedTextTheme(scheme, ThemeData.light().textTheme).copyWith(
      headlineLarge: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F172A),
        letterSpacing: -0.5,
      ),
      titleMedium: const TextStyle(color: Color(0xFF334155)),
      bodyLarge: const TextStyle(color: Color(0xFF475569)),
      bodyMedium: const TextStyle(color: Color(0xFF64748B)),
    ),
  );
}
