/// Test konfigurasi URL API: semua URL HARUS datang dari `.env` /
/// `--dart-define` — tidak ada lagi URL environment yang di-hardcode di kode.
///
/// Regresi untuk kasus: ganti server = harus edit kode; fallback
/// per-platform menyebabkan app Android menunjuk host yang salah.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    // Kembalikan override platform agar tidak bocor ke test lain.
    debugDefaultTargetPlatformOverride = null;
  });

  test('baseUrl diambil dari .env (dotenv), platform desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    dotenv.testLoad(
      fileInput: 'API_BASE_URL=http://server-dari-env.test/api\n',
    );
    expect(ApiConfig.baseUrl, 'http://server-dari-env.test/api');
  });

  test('di Android emulator, host loopback diremap ke 10.0.2.2', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://127.0.0.1:8000/api\n');
    expect(ApiConfig.baseUrl, 'http://10.0.2.2:8000/api');

    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api\n');
    expect(ApiConfig.baseUrl, 'http://10.0.2.2:8000/api');
  });

  test('API_BASE_URL_ANDROID menimpa URL di Android (HP fisik)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dotenv.testLoad(
      fileInput:
          'API_BASE_URL=http://127.0.0.1:8000/api\n'
          'API_BASE_URL_ANDROID=http://192.168.1.10:8000/api\n',
    );
    expect(ApiConfig.baseUrl, 'http://192.168.1.10:8000/api');
  });

  test('di Android, host non-loopback tidak diubah', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://192.168.1.10:8000/api\n');
    expect(ApiConfig.baseUrl, 'http://192.168.1.10:8000/api');
  });

  test('lempar StateError bila API_BASE_URL tidak diatur', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    dotenv.testLoad(fileInput: '');
    expect(() => ApiConfig.baseUrl, throwsStateError);
  });
}
