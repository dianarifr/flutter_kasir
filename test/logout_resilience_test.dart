/// Test ketahanan logout: sesi lokal HARUS terbersihkan & logout tidak
/// boleh melempar exception walau panggilan API ke backend gagal
/// (server mati, token sudah hangus/401, dsb).
///
/// Regresi untuk kasus nyata: logout "gagal" karena exception API
/// menghentikan navigasi ke halaman login.
library;

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/core/services/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Test tidak memuat asset .env; inisialisasi dotenv manual agar
    // ApiConfig.baseUrl (dipakai ApiClient saat menyusun URI) valid.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setToken('token-lama');
  });

  test('logout tetap bersih walau server mati (SocketException)', () async {
    ApiClient.instance.setClient(
      MockClient(
        (request) => throw const SocketException('connection refused'),
      ),
    );

    // Siapkan sesi seperti user yang sedang login.
    AppData.instance.setSession(
      const AuthUser(
        id: 1,
        name: 'Kasir',
        email: 'kasir@kasir.com',
        role: 'kasir',
        outlet: null,
      ),
    );
    await TokenStorage.saveToken('token-lama');
    expect(AppData.instance.currentUser, isNotNull);

    // Logout tidak boleh melempar exception walau API gagal total.
    await AppData.instance.logout();

    expect(AppData.instance.currentUser, isNull);
    expect(await TokenStorage.readToken(), isNull);
    expect(await TokenStorage.readUser(), isNull);
  });

  test('logout tetap bersih walau backend balas 401 (token hangus)', () async {
    ApiClient.instance.setClient(
      MockClient(
        (request) async => http.Response(
          '{"status":"error","message":"Sesi berakhir, silakan login kembali."}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    AppData.instance.setSession(
      const AuthUser(
        id: 1,
        name: 'Kasir',
        email: 'kasir@kasir.com',
        role: 'kasir',
        outlet: null,
      ),
    );
    await TokenStorage.saveToken('token-lama');

    await AppData.instance.logout();

    expect(AppData.instance.currentUser, isNull);
    expect(await TokenStorage.readToken(), isNull);
  });

  test('logout sukses memanggil endpoint /logout', () async {
    var called = false;
    ApiClient.instance.setClient(
      MockClient((request) async {
        expect(request.url.path, endsWith('/api/logout'));
        expect(request.method, 'POST');
        called = true;
        return http.Response('{"message":"Logout berhasil."}', 200);
      }),
    );

    await AppData.instance.logout();
    expect(called, isTrue);
  });

  test(
    'kredensial ingat-saya bertahan setelah logout (prefill login)',
    () async {
      // Simulasi login dengan "Ingat saya" tercentang.
      await TokenStorage.saveCredentials(
        email: 'kasir@kasir.com',
        password: 'kasir123',
        remember: true,
      );
      await TokenStorage.saveToken('token-aktif');

      // Logout menghapus sesi...
      await AppData.instance.logout();

      // ...tapi kredensial tetap ada untuk prefill form login.
      expect(await TokenStorage.readToken(), isNull);
      final creds = await TokenStorage.readCredentials();
      expect(creds.email, 'kasir@kasir.com');
      expect(creds.password, 'kasir123');
      expect(creds.remember, isTrue);
    },
  );

  test('kredensial dihapus bila user memilih tidak ingat saat login', () async {
    // Login pertama dengan remember = true.
    await TokenStorage.saveCredentials(
      email: 'kasir@kasir.com',
      password: 'kasir123',
      remember: true,
    );

    // Login berikutnya dengan remember = false.
    await TokenStorage.saveCredentials(
      email: 'kasir.pandugo@kasir.com',
      password: 'kasir123',
      remember: false,
    );

    final creds = await TokenStorage.readCredentials();
    expect(creds.email, isNull);
    expect(creds.password, isNull);
    expect(creds.remember, isFalse);
  });
}
