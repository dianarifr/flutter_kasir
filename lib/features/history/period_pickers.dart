/// Kumpulan bottom sheet pemilih periode untuk Riwayat Penjualan.
///
/// Semua picker memakai chrome yang sama: sheet putih radius atas, judul,
/// konten, lalu tombol "Batal" + "Terapkan" sama lebar. Kalender memakai
/// widget dari plugin flutter_date_range_picker ditema terakota; bulanan &
/// tahunan memakai grid chip kustom (plugin tidak punya mode bulan/tahun).
///
/// Catatan: wrapper dialog bawaan plugin sengaja tidak dipakai karena
/// tata letaknya rusak di layar sempit (kalender 280px di-rata-kanan di
/// dalam kotak 400px) — widget kalendernya saja yang di-host di sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_date_range_picker/flutter_date_range_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Tema kalender plugin — aksen terakota, teks ink, radius kecil.
const CalendarTheme _kCalendarTheme = CalendarTheme(
  selectedColor: AppColors.accent,
  inRangeColor: Color(0x1AD97757), // aksen 10% untuk hari di rentang
  inRangeTextStyle: TextStyle(color: AppColors.accentPressed, fontSize: 13),
  selectedTextStyle: TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  ),
  todayTextStyle: TextStyle(
    color: AppColors.accent,
    fontWeight: FontWeight.bold,
    fontSize: 13,
  ),
  defaultTextStyle: TextStyle(color: AppColors.ink, fontSize: 13),
  disabledTextStyle: TextStyle(color: AppColors.border),
  dayNameTextStyle: TextStyle(color: AppColors.inkMuted, fontSize: 11),
  monthTextStyle: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
  radius: 8,
  tileSize: 40,
);

/// Picker tanggal harian: cukup ketuk satu hari — rentang dibatasi tepat
/// 1 hari (`maximumDateRangeLength: 1`), jadi setiap ketukan langsung
/// menjadi rentang satu hari.
///
/// Mengembalikan tanggal terpilih, atau `null` bila dibatalkan.
Future<DateTime?> showDailyPickerSheet(
  BuildContext context, {
  DateTime? initial,
}) async {
  final initialDate = initial == null ? null : _dateOnly(initial);
  final range = await _showCalendarSheet(
    context: context,
    title: 'Pilih Tanggal',
    initialRange:
        initialDate == null ? null : DateRange(initialDate, initialDate),
    maximumDateRangeLength: 1,
  );
  return range?.start;
}

/// Picker rentang custom: ketuk tanggal awal lalu tanggal akhir.
/// Mengembalikan [DateRange], atau `null` bila dibatalkan.
Future<DateRange?> showCustomRangePickerSheet(
  BuildContext context, {
  DateRange? initial,
}) {
  return _showCalendarSheet(
    context: context,
    title: 'Pilih Rentang Tanggal',
    initialRange: initial,
  );
}

/// Picker bulanan: grid 24 bulan terakhir. Mengembalikan tanggal hari
/// pertama bulan terpilih, atau `null` bila dibatalkan.
Future<DateTime?> showMonthPickerSheet(BuildContext context, {DateTime? selected}) {
  final now = DateTime.now();
  final options = List.generate(24, (i) => DateTime(now.year, now.month - i, 1));
  return _showGridSheet<DateTime>(
    context: context,
    title: 'Pilih Bulan',
    options: options,
    label: formatMonthYear,
    matches: (option) =>
        selected != null &&
        selected.year == option.year &&
        selected.month == option.month,
  );
}

/// Picker tahunan: grid 10 tahun terakhir.
Future<int?> showYearPickerSheet(BuildContext context, {int? selected}) {
  final options = List.generate(10, (i) => DateTime.now().year - i);
  return _showGridSheet<int>(
    context: context,
    title: 'Pilih Tahun',
    options: options,
    label: (year) => '$year',
    matches: (year) => year == selected,
  );
}

// ---------------------------------------------------------------------------
// Sheet kalender (plugin)
// ---------------------------------------------------------------------------

Future<DateRange?> _showCalendarSheet({
  required BuildContext context,
  required String title,
  DateRange? initialRange,
  int? maximumDateRangeLength,
}) {
  // Pilihan sementara di dalam sheet — di-update lewat setSheetState.
  DateRange? picked = initialRange;

  return _showSheet<DateRange>(
    context: context,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return _sheetBody(
            title: title,
            children: [
              // Tinggi kalender dibatasi manual. Plugin me-render
              // (jumlah minggu + 1) baris tile — baris terakhir selalu
              // placeholder kosong — dan tinggi bawaannya (330) kekecilan
              // 2px untuk tema kita (header 40 + jarak 20+16 + nama hari
              // ~16 + 6x40 = 332). Triknya: kalender diberi ruang longgar
              // (600) supaya isinya tidak pernah overflow, lalu dipotong
              // presisi di 344 — yang terpotong hanya baris placeholder
              // kosong, termasuk saat bulan butuh 6 minggu riil (~372px).
              Container(
                height: 344,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                alignment: Alignment.topCenter,
                child: DateRangePickerWidget(
                  doubleMonth: false, // layar ponsel: satu bulan cukup
                  height: 600,
                  firstDayOfWeek: 1, // mulai Senin
                  maximumDateRangeLength: maximumDateRangeLength,
                  initialDateRange: initialRange,
                  initialDisplayedDate: initialRange?.start ?? DateTime.now(),
                  maxDate: DateTime.now(), // riwayat: tak ada tanggal masa depan
                  theme: _kCalendarTheme,
                  onDateRangeChanged: (range) =>
                      setSheetState(() => picked = range),
                ),
              ),
              _sheetFooter(
                sheetContext: sheetContext,
                enabled: picked != null,
                onApply: () => Navigator.pop(sheetContext, picked),
              ),
            ],
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Sheet grid (bulan / tahun)
// ---------------------------------------------------------------------------

Future<T?> _showGridSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T option) label,
  required bool Function(T option) matches,
}) {
  // Tandai pilihan awal sesuai filter yang sedang aktif.
  T? picked;
  for (final option in options) {
    if (matches(option)) {
      picked = option;
      break;
    }
  }

  return _showSheet<T>(
    context: context,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return _sheetBody(
            title: title,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isPicked = picked == option;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setSheetState(() => picked = option),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isPicked ? AppColors.accent : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isPicked ? Colors.white : AppColors.ink,
                          fontWeight: isPicked ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _sheetFooter(
                sheetContext: sheetContext,
                enabled: picked != null,
                onApply: () => Navigator.pop(sheetContext, picked),
              ),
            ],
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Chrome sheet bersama
// ---------------------------------------------------------------------------

Future<T?> _showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: builder,
  );
}

/// Kerangka isi sheet: judul + konten, bisa discroll bila layar pendek.
Widget _sheetBody({required String title, required List<Widget> children}) {
  return SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

/// Tombol footer sheet: "Batal" + "Terapkan" sama lebar. "Terapkan"
/// mati sampai ada pilihan.
Widget _sheetFooter({
  required BuildContext sheetContext,
  required bool enabled,
  required VoidCallback onApply,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Batal'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: enabled ? onApply : null,
            child: const Text('Terapkan'),
          ),
        ),
      ],
    ),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
