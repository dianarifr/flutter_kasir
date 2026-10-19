/// Konfigurasi endpoint API backend (Laravel kasir-app).
///
/// SEMUA URL dikonfigurasi lewat file `.env` (atau `--dart-define`) —
/// tidak ada URL yang di-hardcode di kode:
/// ```
/// # .env
/// API_BASE_URL=http://127.0.0.1:8000/api
/// # opsional, khusus perangkat Android (mis. HP fisik via IP LAN):
/// API_BASE_URL_ANDROID=http://192.168.1.10:8000/api
/// ```
///
/// `--dart-define` tetap didukung untuk override CLI/CI:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  ApiConfig._();

  /// Base URL API, contoh hasil akhir: `http://127.0.0.1:8000/api`.
  ///
  /// Urutan prioritas:
  /// 1. File `.env` → `API_BASE_URL` (dimuat di `main()` via flutter_dotenv).
  /// 2. `--dart-define=API_BASE_URL=...` (override CLI/CI).
  /// 3. Penyesuaian platform (lihat [_adaptForPlatform]).
  /// 4. Bila semuanya kosong: lempar [StateError] dengan petunjuk perbaikan
  ///    (tidak ada lagi fallback URL yang di-hardcode).
  static String get baseUrl {
    final fromDotenv = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final value = (fromDotenv != null && fromDotenv.isNotEmpty)
        ? fromDotenv
        : fromDefine;

    if (value.isEmpty) {
      throw StateError(
        'API_BASE_URL belum diatur. Tambahkan baris '
        '"API_BASE_URL=<url-server-anda>" di file .env (pastikan .env '
        'terdaftar di assets pubspec.yaml dan dimuat via dotenv.load di '
        'main.dart), atau jalankan dengan '
        '--dart-define=API_BASE_URL=<url-server-anda>.',
      );
    }

    return _adaptForPlatform(value);
  }

  /// Penyesuaian URL per platform, tanpa hardcoded URL environment:
  ///
  /// - Android: `.env` boleh menyediakan override khusus via
  ///   `API_BASE_URL_ANDROID` (mis. HP fisik memakai IP LAN komputer).
  /// - Android emulator: bila URL memakai host loopback
  ///   (`127.0.0.1`/`localhost`), host otomatis diremap ke `10.0.2.2` —
  ///   alias resmi host machine dari dalam emulator Android, sehingga
  ///   satu nilai `API_BASE_URL` di .env cukup untuk semua platform.
  /// - Platform lain: URL dipakai apa adanya.
  static String _adaptForPlatform(String url) {
    if (defaultTargetPlatform != TargetPlatform.android) return url;

    final androidOverride = dotenv.isInitialized
        ? dotenv.env['API_BASE_URL_ANDROID']
        : null;
    if (androidOverride != null && androidOverride.isNotEmpty) {
      return androidOverride;
    }

    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    if (uri != null && (host == 'localhost' || host == '127.0.0.1')) {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return url;
  }

  /// Timeout default untuk setiap request (detik).
  static const Duration timeout = Duration(seconds: 15);
}
