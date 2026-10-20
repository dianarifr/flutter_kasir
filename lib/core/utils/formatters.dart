// Helper format angka & tanggal (tanpa dependency intl).

/// Format Rupiah dengan pemisah ribuan, contoh: 1250000 -> "Rp 1.250.000".
String formatRupiah(int amount) {
  final s = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buffer.write(s[i]);
    final remaining = s.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
  }
  return '${amount < 0 ? '-Rp ' : 'Rp '}$buffer';
}

// ---- Format tanggal (tanpa dependency intl) ----

const List<String> _bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const List<String> _hariSingkat = [
  'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
];

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Format tanggal Indonesia singkat, contoh: "Sen, 20 Okt 2026".
String formatDateShort(DateTime date) {
  return '${_hariSingkat[date.weekday - 1]}, '
      '${date.day} ${_bulanSingkat[date.month - 1]} ${date.year}';
}

/// Format bulan + tahun, contoh: "Okt 2026".
String formatMonthYear(DateTime date) {
  return '${_bulanSingkat[date.month - 1]} ${date.year}';
}

/// Format jam singkat, contoh: "09:15".
String formatTime(DateTime d) => '${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Format tanggal + jam, contoh: "20 Okt 2026, 14:35".
String formatDateTime(DateTime date) {
  return '${date.day} ${_bulanSingkat[date.month - 1]} ${date.year}, '
      '${_pad2(date.hour)}:${_pad2(date.minute)}';
}

/// Format rentang tanggal, contoh: "1 - 20 Okt 2026" atau
/// "28 Sep - 2 Okt 2026" bila beda bulan.
String formatDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${start.day} - ${end.day} ${_bulanSingkat[start.month - 1]} ${start.year}';
  }
  if (start.year == end.year) {
    return '${start.day} ${_bulanSingkat[start.month - 1]} - '
        '${end.day} ${_bulanSingkat[end.month - 1]} ${end.year}';
  }
  return '${formatDateShort(start)} - ${formatDateShort(end)}';
}

/// Format tanggal-waktu singkat, contoh: "19 Okt 2026 14:30".
String formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
}
