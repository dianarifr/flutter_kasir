import 'package:shared_preferences/shared_preferences.dart';

/// Teks penutup struk bawaan bila user belum pernah mengubahnya.
const String kDefaultReceiptFooter = 'Terima kasih telah berbelanja';

/// Sumber teks penutup struk per outlet.
///
/// SEKARANG: disimpan lokal di device lewat `SharedPreferences` supaya
/// perubahan langsung terasa tanpa menunggu backend.
///
/// NANTI (rencana): pindah ke backend per outlet, mis.
/// `GET /outlets/{id}/receipt-settings` & `PUT` dengan payload yang
/// sama. Cukup ganti isi [fetchFooter] & [saveFooter] — pemanggil
/// ([AppData]) dan UI tidak perlu berubah. Bila nanti butuh cache
/// offline, logikanya juga masuk ke sini: fetch API -> simpan cache ->
/// pakai cache bila request gagal.
class ReceiptSettingsService {
  ReceiptSettingsService._();

  static final ReceiptSettingsService instance = ReceiptSettingsService._();

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Key per outlet. Akun tanpa outlet (admin) memakai key global.
  static String _footerKey(int? outletId) => outletId == null
      ? 'receipt_footer_global'
      : 'receipt_footer_outlet_$outletId';

  /// Baca teks penutup untuk [outletId]. Tidak ada / kosong = default.
  Future<String> fetchFooter(int? outletId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_footerKey(outletId))?.trim() ?? '';
    return raw.isEmpty ? kDefaultReceiptFooter : raw;
  }

  /// Simpan teks penutup untuk [outletId]. Teks kosong dinormalkan
  /// menjadi default supaya struk tidak pernah tampil tanpa penutup.
  Future<void> saveFooter(int? outletId, String text) async {
    final prefs = await _prefs;
    await prefs.setString(_footerKey(outletId), normalizeFooter(text));
  }

  /// Nilai yang benar-benar dipakai/disimpan dari input user.
  static String normalizeFooter(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? kDefaultReceiptFooter : trimmed;
  }
}