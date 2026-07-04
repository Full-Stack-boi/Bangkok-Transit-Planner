import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pure, color-scheme-driven builders for shared component styling parameters.
/// Ensures design consistency and eliminates visual code duplication.

AppBarTheme buildSharedAppBarTheme(ColorScheme scheme) {
  return AppBarTheme(
    backgroundColor: scheme.surface,
    foregroundColor: scheme.onSurface,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.outfit(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
  );
}

NavigationBarThemeData buildSharedNavigationBarTheme(ColorScheme scheme, Color cardColor) {
  return NavigationBarThemeData(
    backgroundColor: cardColor,
    elevation: 0,
    indicatorColor: scheme.primary.withValues(alpha: 0.15),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(color: scheme.primary, size: 24);
      }
      return const IconThemeData(
        color: Color(0xFF64748B),
        size: 24,
      ); // Muted Slate Gray
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return GoogleFonts.outfit(
          color: scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        );
      }
      return GoogleFonts.outfit(
        color: const Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
    }),
  );
}

CardThemeData buildSharedCardTheme(ColorScheme scheme, {Color? color, ShapeBorder? shape}) {
  return CardThemeData(
    color: color ?? scheme.surfaceContainerLow,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: shape ?? RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.2), width: 1),
    ),
  );
}

InputDecorationTheme buildSharedInputDecorationTheme(ColorScheme scheme, {Color? fillColor, InputBorder? border, InputBorder? enabledBorder}) {
  return InputDecorationTheme(
    filled: true,
    fillColor: fillColor ?? scheme.surfaceContainerLowest,
    border: border ?? OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
    ),
    enabledBorder: enabledBorder ?? OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B)),
    labelStyle: GoogleFonts.outfit(),
  );
}

ElevatedButtonThemeData buildSharedElevatedButtonTheme(ColorScheme scheme, {required bool isDark}) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: isDark ? Colors.black : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
    ),
  );
}

OutlinedButtonThemeData buildSharedOutlinedButtonTheme(ColorScheme scheme, {BorderSide? borderSide, Color? textColor}) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: textColor ?? scheme.onSurface,
      side: borderSide ?? BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

BottomSheetThemeData buildSharedBottomSheetTheme(ColorScheme scheme, Color cardColor) {
  return BottomSheetThemeData(
    backgroundColor: cardColor,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  );
}

TextTheme buildSharedTextTheme(ColorScheme scheme, TextTheme baseTextTheme) {
  return GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
    headlineLarge: GoogleFonts.outfit(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: scheme.onSurface,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleLarge: GoogleFonts.outfit(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleMedium: GoogleFonts.outfit(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: scheme.onSurface.withValues(alpha: 0.9),
    ),
    bodyLarge: GoogleFonts.outfit(
      fontSize: 16,
      color: scheme.onSurface.withValues(alpha: 0.9),
    ),
    bodyMedium: GoogleFonts.outfit(
      fontSize: 14,
      color: scheme.onSurface.withValues(alpha: 0.6),
    ),
    labelLarge: GoogleFonts.outfit(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}
