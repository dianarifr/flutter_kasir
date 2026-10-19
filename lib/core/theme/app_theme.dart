import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData buildLightTheme() {
  final base = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ).copyWith(primary: AppColors.accent, error: AppColors.error),

    textTheme: base.copyWith(
      headlineLarge: GoogleFonts.lora(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.ink,
      ),
      headlineMedium: GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.ink, fontSize: 16),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.ink, fontSize: 14),
      bodySmall: base.bodySmall?.copyWith(
        color: AppColors.inkMuted,
        fontSize: 12,
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
    ),

    // PERBAIKAN DI SINI: Gunakan CardThemeData
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),

    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      side: BorderSide.none,
      shape: StadiumBorder(),
      labelStyle: TextStyle(color: AppColors.ink, fontSize: 12),
    ),

    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}

ThemeData buildDarkTheme() {
  final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
    ).copyWith(primary: AppColors.accent, error: AppColors.error),

    textTheme: base.copyWith(
      headlineLarge: GoogleFonts.lora(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.darkInk,
      ),
      headlineMedium: GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkInk,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: AppColors.darkInk,
        fontSize: 16,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: AppColors.darkInk,
        fontSize: 14,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: AppColors.darkInkMuted,
        fontSize: 12,
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.darkInk,
    ),

    // PERBAIKAN DI SINI: Gunakan CardThemeData
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkInk,
        side: const BorderSide(color: AppColors.darkBorder),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),

    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.darkSurfaceAlt,
      side: BorderSide.none,
      shape: StadiumBorder(),
      labelStyle: TextStyle(color: AppColors.darkInk, fontSize: 12),
    ),

    dividerTheme: const DividerThemeData(color: AppColors.darkBorder, space: 1),
  );
}
