/// Test penyimpanan daftar akun: dedupe, batas 5 akun, migrasi sesi
/// lama, dan ID perangkat yang stabil.
library;

import 'dart:convert';

import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/services/account_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedAccount _account(
  int id, {
  int lastUsedAt = 0,
  int addedAt = 0,
  String name = 'Kasir',
}) => SavedAccount(
  userId: id,
  token: 'token-$id',
  user: AuthUser(
    id: id,
    name: '$name $id',
    username: 'kasir$id',
    email: 'kasir$id@test.com',
    role: 'kasir',
    outlet: const Outlet(id: 1, name: 'Outlet Pusat'),
  ),
  addedAt: addedAt,
  lastUsedAt: lastUsedAt,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('upsert: akun baru di posisi 0 dan dedupe berdasarkan userId', () async {
    final store = AccountStore.instance;

    await store.upsert(_account(1, addedAt: 111, lastUsedAt: 100));
    await store.upsert(_account(2, addedAt: 222, lastUsedAt: 200));

    var accounts = await store.readAccounts();
    expect(accounts.map((a) => a.userId), [2, 1]);

    // Login ulang akun yang sama: tidak menumpuk, pindah ke atas, dan
    // waktu pertama ditambahkan dipertahankan.
    await store.upsert(_account(1, addedAt: 999, lastUsedAt: 300));

    accounts = await store.readAccounts();
    expect(accounts.map((a) => a.userId), [1, 2]);
    expect(accounts.first.lastUsedAt, 300);
    expect(accounts.first.addedAt, 111);
  });

  test('upsert: maksimal 5 akun, buang lastUsedAt paling lama', () async {
    final store = AccountStore.instance;

    for (var id = 1; id <= 5; id++) {
      await store.upsert(_account(id, lastUsedAt: id * 100));
    }

    await store.upsert(_account(6, lastUsedAt: 1000));

    final accounts = await store.readAccounts();
    expect(accounts.length, AccountStore.maxAccounts);
    expect(accounts.map((a) => a.userId), [6, 5, 4, 3, 2]);
    expect(accounts.any((a) => a.userId == 1), isFalse);
  });

  test('remove: menghapus akun dan mengosongkan status aktif', () async {
    final store = AccountStore.instance;
    await store.upsert(_account(1, lastUsedAt: 100));
    await store.setActive(1);

    await store.remove(1);

    expect(await store.readAccounts(), isEmpty);
    expect(await store.readActiveId(), isNull);
  });

  test('migrateLegacy: sesi lama jadi akun pertama lalu key lama dibersihkan',
      () async {
    final legacyUser = {
      'id': 7,
      'name': 'Kasir Lama',
      'username': 'kasirlama',
      'email': 'lama@test.com',
      'role': 'kasir',
      'outlet': {'id': 1, 'name': 'Outlet Pusat', 'address': ''},
    };
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token-lama',
      'auth_user': jsonEncode(legacyUser),
      'remembered_password': 'password-plaintext-lama',
    });

    await AccountStore.instance.migrateLegacy();

    final accounts = await AccountStore.instance.readAccounts();
    expect(accounts.length, 1);
    expect(accounts.first.userId, 7);
    expect(accounts.first.token, 'token-lama');
    expect(accounts.first.user.outlet?.name, 'Outlet Pusat');
    expect(await AccountStore.instance.readActiveId(), 7);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('auth_user'), isNull);
    // Password plaintext versi lama ikut dibersihkan.
    expect(prefs.getString('remembered_password'), isNull);

    // Idempotent: dipanggil lagi tidak menggandakan akun.
    await AccountStore.instance.migrateLegacy();
    expect((await AccountStore.instance.readAccounts()).length, 1);
  });

  test('deviceId: dibuat sekali lalu stabil', () async {
    final first = await AccountStore.instance.deviceId();
    final second = await AccountStore.instance.deviceId();

    expect(first, isNotEmpty);
    expect(second, first);
  });
}