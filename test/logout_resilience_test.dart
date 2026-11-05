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
import 'package:flutter_kasir/core/services/account_store.dart';
import 'package:flutter_kasir/core/services/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simpan satu akun tersimpan + jadikan aktif (meniru sesi login).
Future<SavedAccount> _saveAccount({
  int userId = 1,
  String token = 'token-lama',
  String name = 'Kasir',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final user = AuthUser(
    id: userId,
    name: name,
    username: 'kasir',
    email: 'kasir@kasir.com',
    role: 'kasir',
    outlet: const Outlet(id: 1, name: 'Outlet Pusat'),
  );
  final account = SavedAccount(
    userId: userId,
    token: token,
    user: user,
    addedAt: now,
    lastUsedAt: now,
  );
  await AccountStore.instance.upsert(account);
  await AccountStore.instance.setActive(userId);
  return account;
}

void main() {
  setUp(() {
    // Test tidak memuat asset .env; inisialisasi dotenv manual agar
    // ApiConfig.baseUrl (dipakai ApiClient saat menyusun URI) valid.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setToken('token-lama');
    ApiClient.instance.onUnauthorized = null;
  });

  test('logout tetap bersih walau server mati (SocketException)', () async {
    ApiClient.instance.setClient(
      MockClient(
        (request) => throw const SocketException('connection refused'),
      ),
    );

    // Siapkan sesi seperti user yang sedang login.
    final account = await _saveAccount();
    AppData.instance.setSession(account.user);
    expect(AppData.instance.currentUser, isNotNull);

    // Logout tidak boleh melempar exception walau API gagal total.
    await AppData.instance.logout();

    expect(AppData.instance.currentUser, isNull);
    expect(await AccountStore.instance.readAccounts(), isEmpty);
    expect(await AccountStore.instance.readActive(), isNull);
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

    final account = await _saveAccount();
    AppData.instance.setSession(account.user);

    await AppData.instance.logout();

    expect(AppData.instance.currentUser, isNull);
    expect(await AccountStore.instance.readAccounts(), isEmpty);
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

  test('username ingat-saya bertahan setelah logout (prefill login)', () async {
    await TokenStorage.saveRemembered(username: 'kasir', remember: true);

    // Logout (tanpa akun tersimpan) tetap boleh berjalan.
    await AppData.instance.logout();

    // Username tetap ada untuk prefill; password tidak pernah disimpan.
    final remembered = await TokenStorage.readRemembered();
    expect(remembered.username, 'kasir');
    expect(remembered.remember, isTrue);
  });

  test('username dihapus bila user memilih tidak ingat saat login', () async {
    // Login pertama dengan remember = true.
    await TokenStorage.saveRemembered(username: 'kasir', remember: true);

    // Login berikutnya dengan remember = false.
    await TokenStorage.saveRemembered(username: 'pandugo', remember: false);

    final remembered = await TokenStorage.readRemembered();
    expect(remembered.username, isNull);
    expect(remembered.remember, isFalse);
  });
}