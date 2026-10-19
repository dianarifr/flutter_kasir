import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  // Title (Lora Serif)
  static TextStyle titleLarge = GoogleFonts.lora(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.ink,
  );

  static TextStyle titleMedium = GoogleFonts.lora(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  // Body & Tabular Numbers (Inter)
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    color: AppColors.ink,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    color: AppColors.ink,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.inkMuted,
  );

  // Khusus Harga/Angka Kasir (Menggunakan Tabular Figures agar angka sejajar)
  static TextStyle priceTag = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
