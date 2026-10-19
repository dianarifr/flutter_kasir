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
