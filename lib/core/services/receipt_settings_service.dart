import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Teks penutup struk bawaan bila outlet belum pernah mengubahnya.
const String kDefaultReceiptFooter = 'Terima kasih telah berbelanja';

/// Sumber teks penutup struk per outlet.
///
/// Backend (`GET`/`PUT /receipt-settings`, outlet diambil dari token) adalah
/// sumber kebenaran. `SharedPreferences` hanya dipakai sebagai **cache**:
///
/// - struk tidak perlu menunggu jaringan saat dibuka,
/// - teks lama tetap tampil walau backend sedang tidak terjangkau.
///
/// [fetchFooter] tidak pernah melempar — cache dipakai bila API gagal.
/// [saveFooter] melempar [ApiException] karena user harus tahu saat
/// perubahannya tidak tersimpan di server.
class ReceiptSettingsService {
  ReceiptSettingsService._();

  static final ReceiptSettingsService instance = ReceiptSettingsService._();

  final ApiClient _client = ApiClient.instance;

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Key cache per outlet. Akun tanpa outlet (admin) memakai key global.
  static String _footerKey(int? outletId) => outletId == null
      ? 'receipt_footer_global'
      : 'receipt_footer_outlet_$outletId';

  /// Teks penutup untuk [outletId].
  ///
  /// Urutan: API -> cache -> default. Hasil dari API selalu ditulis ke
  /// cache supaya pemakaian berikutnya instan.
  ///
  /// Akun tanpa outlet tidak punya endpoint (backend menolak 422), jadi
  /// langsung memakai cache/default tanpa request.
  Future<String> fetchFooter(int? outletId) async {
    if (outletId != null) {
      try {
        final body = await _client.get('/receipt-settings');
        final data = (body as Map<String, dynamic>)['data'];
        final raw = data is Map<String, dynamic>
            ? (data['receipt_footer'] as String?)
            : null;
        await _writeCache(outletId, raw ?? '');
        return normalizeFooter(raw ?? '');
      } catch (_) {
        // Offline / server bermasalah: pakai teks terakhir yang diketahui.
      }
    }
    return _readCache(outletId);
  }

  /// Simpan teks penutup untuk [outletId] ke backend lalu perbarui cache.
  ///
  /// Melempar [ApiException] bila server menolak, supaya UI bisa memberi
  /// tahu bahwa perubahan belum tersimpan. Cache **tidak** diubah saat
  /// gagal — tampilan tetap konsisten dengan isi server.
  Future<void> saveFooter(int? outletId, String text) async {
    final trimmed = text.trim();

    if (outletId == null) {
      // Tidak ada endpoint untuk akun tanpa outlet; simpan lokal saja.
      await _writeCache(outletId, trimmed);
      return;
    }

    // Teks kosong dikirim apa adanya supaya backend menyimpannya sebagai
    // null (= pakai teks bawaan), bukan tersimpan sebagai string default.
    final body = await _client.put(
      '/receipt-settings',
      body: {'receipt_footer': trimmed},
    );
    final data = (body as Map<String, dynamic>)['data'];
    final saved = data is Map<String, dynamic>
        ? (data['receipt_footer'] as String?)
        : null;
    await _writeCache(outletId, saved ?? '');
  }

  /// Unggah teks yang dulu tersimpan lokal ke backend, sekali saja.
  ///
  /// Sebelum fitur ini, teks disimpan hanya di device. Kalau backend masih
  /// kosong (`receipt_footer` null) sementara cache berisi teks yang bukan
  /// default, teks itu dikirim agar tidak hilang saat versi lama diganti.
  ///
  /// Mengembalikan `true` bila benar-benar mengunggah sesuatu.
  Future<bool> uploadLocalFooterIfMissing(int? outletId) async {
    if (outletId == null) return false;

    final local = await _readCacheRaw(outletId);
    if (local == null || local == kDefaultReceiptFooter) return false;

    try {
      final body = await _client.get('/receipt-settings');
      final data = (body as Map<String, dynamic>)['data'];
      final server = data is Map<String, dynamic>
          ? (data['receipt_footer'] as String?)
          : null;
      if (server != null && server.trim().isNotEmpty) return false;

      await saveFooter(outletId, local);
      return true;
    } catch (_) {
      // Backend belum terjangkau: biarkan cache apa adanya, coba lagi
      // pada pemuatan berikutnya.
      return false;
    }
  }

  /// Nilai yang benar-benar dipakai/disimpan dari input user.
  static String normalizeFooter(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? kDefaultReceiptFooter : trimmed;
  }

  Future<String> _readCache(int? outletId) async =>
      normalizeFooter(await _readCacheRaw(outletId) ?? '');

  /// Nilai mentah cache (`null` bila belum pernah ditulis).
  Future<String?> _readCacheRaw(int? outletId) async {
    final prefs = await _prefs;
    return prefs.getString(_footerKey(outletId));
  }

  Future<void> _writeCache(int? outletId, String value) async {
    final prefs = await _prefs;
    await prefs.setString(_footerKey(outletId), value);
  }
}