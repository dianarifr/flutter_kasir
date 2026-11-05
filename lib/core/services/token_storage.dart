/// Penyimpanan lokal untuk preferensi form login ("Ingat saya").
///
/// Password TIDAK pernah disimpan. Data sesi (token + user) sekarang
/// dikelola [AccountStore]; key lama `auth_token` / `auth_user` hanya
/// dibaca sekali oleh `AccountStore.migrateLegacy()`.
library;

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const _rememberedUsernameKey = 'remembered_username';
  static const _rememberMeKey = 'remember_me';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Simpan username untuk prefill form login.
  ///
  /// `remember = false` menghapus prefill lama (user menolak diingat).
  /// Password tidak ikut disimpan dalam kondisi apa pun.
  static Future<void> saveRemembered({
    required String username,
    required bool remember,
  }) async {
    final prefs = await _prefs;
    if (remember) {
      await prefs.setString(_rememberedUsernameKey, username);
      await prefs.setBool(_rememberMeKey, true);
    } else {
      await prefs.remove(_rememberedUsernameKey);
      await prefs.setBool(_rememberMeKey, false);
    }
  }

  /// Username terakhir yang diingat + status checkbox terakhir.
  static Future<({String? username, bool remember})> readRemembered() async {
    final prefs = await _prefs;
    return (
      username: prefs.getString(_rememberedUsernameKey),
      remember: prefs.getBool(_rememberMeKey) ?? true,
    );
  }

  /// Hapus preferensi "Ingat saya" (mis. saat user ubah checkbox).
  static Future<void> clearRemembered() async {
    final prefs = await _prefs;
    await prefs.remove(_rememberedUsernameKey);
    await prefs.remove(_rememberMeKey);
  }

  /// Hapus password plaintext yang dulu disimpan versi lama. Dipanggil
  /// sekali saat migrasi akun supaya data sensitif tidak tertinggal.
  static Future<void> removeLegacyPassword() async {
    final prefs = await _prefs;
    await prefs.remove('remembered_password');
  }
}