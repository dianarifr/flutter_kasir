import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache persisten sederhana di atas shared_preferences untuk data master
/// yang jarang berubah (produk, charge): payload JSON + waktu simpan.
/// Pemakainya (AppData) yang memutuskan segar/basi dan kapan fetch ulang.
class LocalCache {
  LocalCache._();

  static final LocalCache instance = LocalCache._();

  Future<void> writeJson(String key, Object payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(payload));
    await prefs.setInt(_stampKey(key), DateTime.now().millisecondsSinceEpoch);
  }

  /// Baca cache beserta waktu simpannya; `null` bila belum pernah
  /// disimpan atau isinya bukan JSON valid, sehingga pemanggil cukup
  /// memerlakukan null sebagai "tidak ada cache".
  Future<CacheEntry?> readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    final stamp = prefs.getInt(_stampKey(key));
    if (raw == null || stamp == null) return null;
    try {
      return CacheEntry(
        jsonDecode(raw),
        DateTime.fromMillisecondsSinceEpoch(stamp),
      );
    } catch (_) {
      // Cache rusak (data terpotong/versi lama): dianggap tidak ada
      // agar alur fetch normal tetap berjalan.
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(_stampKey(key));
  }

  String _stampKey(String key) => '$key.saved_at';
}

/// Isi cache beserta kapan ia disimpan.
class CacheEntry {
  final Object payload;
  final DateTime savedAt;

  const CacheEntry(this.payload, this.savedAt);
}
