/// Service autentikasi: komunikasi dengan endpoint login/logout API dan
/// pengelolaan daftar akun tersimpan di perangkat.
library;

import 'dart:async';

import '../data/models.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'account_store.dart';
import 'token_storage.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final ApiClient _client = ApiClient.instance;

  /// Login ke backend, simpan token + data user, lalu kembalikan user.
  ///
  /// Backend memvalidasi [username] (bukan email). [deviceName] wajib
  /// oleh backend; `device_id` stabil per perangkat dikirim agar token
  /// tiap perangkat terpisah dan tidak saling menghapus.
  ///
  /// [remember] = `true` menyimpan akun ke daftar akun (auto-login &
  /// quick switch). `false` = token hanya hidup selama app berjalan.
  Future<AuthUser> login({
    required String username,
    required String password,
    String deviceName = 'Nyemil Nyam',
    bool remember = true,
  }) async {
    final deviceId = await AccountStore.instance.deviceId();
    final body = await _client.post(
      '/login',
      body: {
        'username': username,
        'password': password,
        'device_name': deviceName,
        'device_id': deviceId,
      },
      // 401 di sini berarti username/password salah, bukan sesi hangus;
      // jangan sampai memicu pembersihan akun yang sedang aktif.
      notifyOnUnauthorized: false,
    );

    final data = (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

    // Terapkan token ke client agar langsung bisa dipakai sesi ini.
    _client.setToken(token);

    // Username disimpan untuk prefill; password tidak pernah disimpan.
    await TokenStorage.saveRemembered(username: username, remember: remember);

    if (remember) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await AccountStore.instance.upsert(
        SavedAccount(
          userId: user.id,
          token: token,
          user: user,
          addedAt: now,
          lastUsedAt: now,
        ),
      );
      await AccountStore.instance.setActive(user.id);
    } else {
      // Sesi sementara: jangan tinggalkan akun ini di daftar (token
      // perangkat ini baru saja diganti server, entri lama sudah mati).
      await AccountStore.instance.remove(user.id);
      await AccountStore.instance.setActive(null);
    }

    return user;
  }

  /// Pindah ke akun tersimpan berdasarkan [userId].
  ///
  /// Token akun dipakai untuk memvalidasi `GET /user-info`. Bila token
  /// hangus (401) akun dihapus dan [ApiException] dilempar. Bila gagal
  /// karena jaringan, data cache dipakai (mode offline).
  Future<SavedAccount> switchAccount(int userId) async {
    final accounts = await AccountStore.instance.readAccounts();
    SavedAccount? account;
    for (final item in accounts) {
      if (item.userId == userId) {
        account = item;
        break;
      }
    }
    if (account == null) {
      throw const ApiException(
        'Akun tidak ditemukan di perangkat ini.',
        statusCode: 404,
      );
    }

    final previousToken = _client.token;
    _client.setToken(account.token);

    try {
      final body = await _client.get(
        '/user-info',
        // 401 ditangani di sini (hapus akun ini saja), bukan oleh
        // handler sesi hangus global.
        notifyOnUnauthorized: false,
      );
      final user = AuthUser.fromJson(body as Map<String, dynamic>);
      final updated = account.copyWith(
        user: user,
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await AccountStore.instance.upsert(updated);
      await AccountStore.instance.setActive(userId);
      return updated;
    } on ApiException catch (e) {
      _client.setToken(previousToken);
      if (e.statusCode == 401) {
        await AccountStore.instance.remove(userId);
        await AccountStore.instance.setActive(
          await AccountStore.instance.readActiveId(),
        );
        throw ApiException(
          'Sesi akun ${account.user.name} sudah berakhir. '
          'Silakan login ulang untuk akun itu.',
          statusCode: 401,
        );
      }
      rethrow;
    } catch (_) {
      // Jaringan mati/timeout: tetap pindah memakai data cache.
      final updated = account.copyWith(
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await AccountStore.instance.upsert(updated);
      await AccountStore.instance.setActive(userId);
      return updated;
    }
  }

  /// Logout perangkat ini: cabut token aktif, hapus akun aktif dari
  /// daftar, lalu otomatis pindah ke akun tersimpan berikutnya.
  ///
  /// Mengembalikan akun baru yang aktif, atau `null` bila tidak ada
  /// akun lain (app harus ke halaman login).
  Future<SavedAccount?> logout() async {
    final active = await AccountStore.instance.readActive();

    try {
      // Revoke token perangkat ini saja (bukan semua perangkat).
      // 401 di sini berarti token sudah hangus — alur logout lokal di
      // bawah tetap jalan, jangan memicu handler sesi hangus global.
      await _client.post('/logout', notifyOnUnauthorized: false);
    } catch (_) {
      // Server mati / token sudah hangus: logout lokal tetap jalan.
    }

    if (active != null) {
      await AccountStore.instance.remove(active.userId);
    }
    _client.setToken(null);

    return _switchToNextSaved();
  }

  /// Logout dari semua akun/perangkat: cabut seluruh token user di
  /// backend lalu hapus daftar akun lokal.
  Future<void> logoutAll() async {
    try {
      await _client.post('/logout-all', notifyOnUnauthorized: false);
    } catch (_) {
      // Tetap bersihkan lokal walau backend tidak terjangkau.
    }
    _client.setToken(null);
    await AccountStore.instance.clearAll();
  }

  /// Muat sesi tersimpan untuk auto-login.
  ///
  /// Migrasi sesi lama dijalankan lebih dulu supaya user yang sudah
  /// login tidak ter-logout setelah update. Validasi token dilakukan
  /// di latar belakang agar app tetap terbuka cepat.
  Future<AuthUser?> restoreSession() async {
    await AccountStore.instance.migrateLegacy();

    final active = await AccountStore.instance.readActive();
    await AccountStore.instance.setActive(active?.userId);
    if (active == null) return null;

    _client.setToken(active.token);
    unawaited(_refreshActiveInBackground(active));
    return active.user;
  }

  /// Dipanggil ApiClient saat request ber-token dibalas 401.
  ///
  /// Menghapus HANYA akun aktif. Bila ada akun lain, pindah diam-diam
  /// dan kembalikan `true`; bila tidak ada, `false` (app ke login).
  Future<bool> handleUnauthorized() async {
    final activeId = await AccountStore.instance.readActiveId();
    if (activeId != null) {
      await AccountStore.instance.remove(activeId);
    }
    _client.setToken(null);

    final next = await _switchToNextSaved();
    return next != null;
  }

  /// Terapkan token akun yang baru dipilih ke client.
  void applyToken(String token) => _client.setToken(token);

  /// Bersihkan token di memori + akun aktif, tanpa memanggil API.
  Future<void> clearLocalSession() async {
    final activeId = await AccountStore.instance.readActiveId();
    if (activeId != null) {
      await AccountStore.instance.remove(activeId);
    }
    _client.setToken(null);
  }

  /// Coba pindah ke akun tersimpan teratas; akun dengan token hangus
  /// dilewati (sudah dihapus oleh [switchAccount]).
  Future<SavedAccount?> _switchToNextSaved() async {
    while (true) {
      final accounts = await AccountStore.instance.readAccounts();
      if (accounts.isEmpty) {
        await AccountStore.instance.setActive(null);
        return null;
      }

      try {
        return await switchAccount(accounts.first.userId);
      } on ApiException catch (e) {
        if (e.statusCode == 401) continue;
        rethrow;
      }
    }
  }

  /// Validasi token akun aktif di latar belakang dan segarkan data user.
  /// Kegagalan (offline / token hangus) diabaikan — 401 akan ditangani
  /// saat request nyata berikutnya.
  Future<void> _refreshActiveInBackground(SavedAccount account) async {
    try {
      final body = await _client.get(
        '/user-info',
        notifyOnUnauthorized: false,
      );
      // Akun sudah berganti selama request berjalan: jangan timpa.
      if (_client.token != account.token) return;

      final user = AuthUser.fromJson(body as Map<String, dynamic>);
      await AccountStore.instance.upsert(account.copyWith(user: user));
    } catch (_) {
      // Diamkan: sesi cache tetap dipakai.
    }
  }
}