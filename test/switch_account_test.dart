/// Test alur multi-akun: logout auto-switch, penanganan 401, token
/// hangus saat ganti akun, dan perilaku "Ingat saya" = false.
library;

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/core/network/api_exception.dart';
import 'package:flutter_kasir/core/services/account_store.dart';
import 'package:flutter_kasir/core/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _userJson(int id, String name, {String username = ''}) => {
  'id': id,
  'name': name,
  'username': username.isEmpty ? 'user$id' : username,
  'email': 'user$id@test.com',
  'role': 'kasir',
  'outlet': {'id': 10 + id, 'name': 'Outlet $id', 'address': ''},
};

AuthUser _user(int id, String name) =>
    AuthUser.fromJson(_userJson(id, name));

Future<SavedAccount> _saveAccount(
  int id,
  String name,
  String token, {
  bool active = false,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final account = SavedAccount(
    userId: id,
    token: token,
    user: _user(id, name),
    addedAt: now,
    lastUsedAt: now,
  );
  await AccountStore.instance.upsert(account);
  if (active) await AccountStore.instance.setActive(id);
  return account;
}

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setToken(null);
    ApiClient.instance.onUnauthorized = null;
  });

  test('logout auto-switch ke akun tersimpan lain', () async {
    final a = await _saveAccount(1, 'Budi', 'token-a', active: true);
    await _saveAccount(2, 'Sari', 'token-b');
    ApiClient.instance.setToken(a.token);
    AppData.instance.setSession(a.user);

    final seenTokens = <String>[];
    ApiClient.instance.setClient(
      MockClient((request) async {
        seenTokens.add(request.headers['Authorization'] ?? '');
        if (request.url.path.endsWith('/logout')) {
          return _jsonResponse({'message': 'Logout berhasil.'});
        }
        if (request.url.path.endsWith('/user-info')) {
          return _jsonResponse(_userJson(2, 'Sari'));
        }
        return _jsonResponse({'message': 'not found'}, 404);
      }),
    );

    await AppData.instance.logout();

    expect(AppData.instance.currentUser?.id, 2);
    expect(await AccountStore.instance.readActiveId(), 2);
    expect(
      (await AccountStore.instance.readAccounts()).map((a) => a.userId),
      [2],
    );
    expect(ApiClient.instance.token, 'token-b');
    expect(seenTokens, contains('Bearer token-a'));
    expect(seenTokens, contains('Bearer token-b'));
  });

  test('401 hanya menghapus akun aktif lalu pindah diam-diam', () async {
    await _saveAccount(1, 'Budi', 'token-a', active: true);
    await _saveAccount(2, 'Sari', 'token-b');
    ApiClient.instance.setToken('token-a');

    ApiClient.instance.setClient(
      MockClient(
        (request) async => _jsonResponse(_userJson(2, 'Sari')),
      ),
    );

    final handled = await AuthService.instance.handleUnauthorized();

    expect(handled, isTrue);
    expect(
      (await AccountStore.instance.readAccounts()).map((a) => a.userId),
      [2],
    );
    expect(await AccountStore.instance.readActiveId(), 2);
    expect(ApiClient.instance.token, 'token-b');
  });

  test('token hangus saat ganti akun: akun dihapus, token lama dipulihkan',
      () async {
    await _saveAccount(1, 'Budi', 'token-a', active: true);
    await _saveAccount(2, 'Sari', 'token-b');
    ApiClient.instance.setToken('token-a');

    ApiClient.instance.setClient(
      MockClient(
        (request) async =>
            _jsonResponse({'message': 'Unauthenticated.'}, 401),
      ),
    );

    await expectLater(
      AuthService.instance.switchAccount(2),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );

    // Hanya akun tujuan (token hangus) yang dihapus; akun aktif tetap.
    expect(
      (await AccountStore.instance.readAccounts()).map((a) => a.userId),
      [1],
    );
    expect(await AccountStore.instance.readActiveId(), 1);
    expect(ApiClient.instance.token, 'token-a');
  });

  test('401 terlambat dari sesi lama tidak menghapus token akun baru',
      () async {
    ApiClient.instance.setToken('token-lama');
    var handled = 0;
    ApiClient.instance.onUnauthorized = () async {
      handled++;
      return true;
    };

    ApiClient.instance.setClient(
      MockClient((request) async {
        // Akun sudah berganti selagi request lama berjalan.
        ApiClient.instance.setToken('token-baru');
        return _jsonResponse({'message': 'Unauthenticated.'}, 401);
      }),
    );

    await expectLater(
      ApiClient.instance.get('/orders'),
      throwsA(isA<ApiException>()),
    );

    expect(ApiClient.instance.token, 'token-baru');
    expect(handled, 0);
  });

  test('login remember=false tidak menyimpan akun (token di memori saja)',
      () async {
    await _saveAccount(1, 'Budi', 'token-a', active: true);

    Map<String, dynamic>? sentBody;
    ApiClient.instance.setClient(
      MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({
          'status': 'success',
          'message': 'Login berhasil.',
          'data': {'user': _userJson(2, 'Sari'), 'token': 'token-sari'},
        });
      }),
    );

    final user = await AuthService.instance.login(
      username: 'sari',
      password: 'rahasia',
      remember: false,
    );

    expect(user.id, 2);
    expect(ApiClient.instance.token, 'token-sari');
    expect(sentBody?['device_id'], isA<String>());
    expect((sentBody?['device_id'] as String).isNotEmpty, isTrue);

    // Tidak tersimpan sebagai akun; status aktif dikosongkan agar app
    // tidak auto-login ke akun lama saat dibuka lagi.
    expect(
      (await AccountStore.instance.readAccounts()).map((a) => a.userId),
      [1],
    );
    expect(await AccountStore.instance.readActiveId(), isNull);
  });

  test('login remember=true menyimpan akun dan menjadikannya aktif', () async {
    ApiClient.instance.setClient(
      MockClient(
        (request) async => _jsonResponse({
          'status': 'success',
          'message': 'Login berhasil.',
          'data': {'user': _userJson(3, 'Andi'), 'token': 'token-andi'},
        }),
      ),
    );

    await AuthService.instance.login(
      username: 'andi',
      password: 'rahasia',
      remember: true,
    );

    final accounts = await AccountStore.instance.readAccounts();
    expect(accounts.length, 1);
    expect(accounts.first.userId, 3);
    expect(accounts.first.token, 'token-andi');
    expect(await AccountStore.instance.readActiveId(), 3);
  });
}