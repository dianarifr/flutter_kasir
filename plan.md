# Plan: Tema UI Aplikasi Kasir (Flutter)

Fokus dokumen ini hanya tampilan: gaya **warm minimal / editorial** ala Claude. Krem lembut, satu aksen terakota, judul serif, border tipis.

---

## 1. Palet Warna

| Peran | Hex | Catatan |
|---|---|---|
| Background | `#FAF9F5` | krem terang |
| Surface (kartu) | `#FFFFFF` | border tipis |
| Surface alt | `#F0EEE6` | panel, chip |
| Border | `#E5E2D8` | 1 px |
| Teks utama | `#141413` | |
| Teks sekunder | `#6B6A63` | |
| Aksen | `#D97757` | tombol utama |
| Aksen tekan | `#C15F3C` | pressed |
| Sukses | `#4F7A5A` | |
| Error | `#B3402F` | |

**Dark mode:** background `#1F1E1D`, surface `#2A2927`, border `#3A3936`, teks `#F5F4ED`, aksen tetap `#D97757`.

## 2. Tipografi

- Judul: serif, **Lora** atau **Source Serif 4**
- Isi dan angka: **Inter** (angka pakai tabular figures)
- Skala: 28 / 20 / 16 / 14 / 12

## 3. Gaya Komponen

- Radius: kartu 12, tombol dan chip pill (999)
- Tanpa bayangan; pakai border 1 px
- Tombol utama: terakota, teks putih. Tombol sekunder: outline
- Input: latar putih, border `#E5E2D8`, fokus border terakota
- Animasi halus 150-200 ms
- Ikon garis tipis (Lucide / Phosphor)
- Spasi lega, kelipatan 4/8

## 4. Struktur File

```
lib/core/theme/
  app_colors.dart
  app_text_styles.dart
  app_theme.dart      # lightTheme & darkTheme
```

## 5. Kode Dasar

**app_colors.dart**
```dart
import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFAF9F5);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF0EEE6);
  static const border = Color(0xFFE5E2D8);
  static const ink = Color(0xFF141413);
  static const inkMuted = Color(0xFF6B6A63);
  static const accent = Color(0xFFD97757);
  static const accentPressed = Color(0xFFC15F3C);
  static const success = Color(0xFF4F7A5A);
  static const error = Color(0xFFB3402F);
}
```

**app_theme.dart**
```dart
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
      headlineLarge: GoogleFonts.lora(fontSize: 28, color: AppColors.ink),
      headlineMedium: GoogleFonts.lora(fontSize: 20, color: AppColors.ink),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.ink),
      bodySmall: base.bodySmall?.copyWith(color: AppColors.inkMuted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
    ),
    cardTheme: CardTheme(
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
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
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
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}
```

## 6. Langkah Kerja

1. Buat project Flutter, tambah `google_fonts`
2. Buat 3 file tema di atas
3. Pasang di `MaterialApp(theme: buildLightTheme())`
4. Buat satu halaman contoh (kartu produk, tombol, input, chip) untuk mengecek tampilan
5. Tambah `buildDarkTheme()` setelah tema terang sudah pas
6. Baru lanjut ke fitur kasir