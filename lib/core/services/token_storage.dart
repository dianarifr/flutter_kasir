/// Penyimpanan lokal untuk sesi login (token & data user).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper [SharedPreferences] untuk data sesi.
///
/// Menggunakan `async` API dari SharedPreferences (best practice
/// agar tidak memblokir UI thread di platform mobile).
class TokenStorage {
  TokenStorage._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  // Kredensial "Ingat saya" — sengaja dipisah dari sesi agar TIDAK ikut
  // terhapus saat logout (prefill form login setelah logout).
  static const _rememberedUsernameKey = 'remembered_username';
  static const _rememberedPasswordKey = 'remembered_password';
  static const _rememberMeKey = 'remember_me';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Simpan token Sanctum hasil login.
  static Future<void> saveToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(_tokenKey, token);
  }

  /// Ambil token yang tersimpan, atau `null` jika belum login.
  static Future<String?> readToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey);
  }

  /// Simpan data user (JSON) untuk tampilan offline-first.
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Ambil data user yang tersimpan, atau `null` jika belum login.
  static Future<Map<String, dynamic>?> readUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Hapus seluruh sesi (dipakai saat logout).
  ///
  /// Kredensial "Ingat saya" sengaja dipertahankan agar form login tetap
  /// terisi setelah logout. Gunakan [clearCredentials] untuk menghapusnya.
  static Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Simpan kredensial untuk fitur "Ingat saya".
  ///
  /// `remember = true`  → username + password disimpan (prefill di login page).
  /// `remember = false` → kredensial lama dihapus (user menolak diingat).
  static Future<void> saveCredentials({
    required String username,
    required String password,
    required bool remember,
  }) async {
    final prefs = await _prefs;
    if (remember) {
      await prefs.setString(_rememberedUsernameKey, username);
      await prefs.setString(_rememberedPasswordKey, password);
      await prefs.setBool(_rememberMeKey, true);
    } else {
      await prefs.remove(_rememberedUsernameKey);
      await prefs.remove(_rememberedPasswordKey);
      await prefs.setBool(_rememberMeKey, false);
    }
  }

  /// Ambil kredensial tersimpan untuk prefill form login.
  ///
  /// Mengembalikan record berisi username/password (bisa `null` bila belum
  /// pernah login dengan "Ingat saya") dan status checkbox terakhir.
  static Future<({String? username, String? password, bool remember})>
  readCredentials() async {
    final prefs = await _prefs;
    return (
      username: prefs.getString(_rememberedUsernameKey),
      password: prefs.getString(_rememberedPasswordKey),
      remember: prefs.getBool(_rememberMeKey) ?? true,
    );
  }

  /// Hapus kredensial "Ingat saya" (mis. user ubah checkbox jadi tidak ingat).
  static Future<void> clearCredentials() async {
    final prefs = await _prefs;
    await prefs.remove(_rememberedUsernameKey);
    await prefs.remove(_rememberedPasswordKey);
    await prefs.remove(_rememberMeKey);
  }
}
