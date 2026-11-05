/// Penyimpanan daftar akun yang login di perangkat ini (maks 5).
///
/// Menggantikan peran `TokenStorage` untuk data sesi: tiap akun menyimpan
/// token + data user-nya sendiri, sehingga berpindah akun tidak perlu
/// mengetik password lagi. Password TIDAK pernah disimpan.
library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'token_storage.dart';

/// Satu akun tersimpan di perangkat.
class SavedAccount {
  final int userId;
  final String token;
  final AuthUser user;

  /// Waktu pertama kali akun ditambahkan (ms sejak epoch).
  final int addedAt;

  /// Waktu terakhir akun dipakai — dasar pemilihan akun yang dibuang
  /// saat daftar melewati batas.
  final int lastUsedAt;

  const SavedAccount({
    required this.userId,
    required this.token,
    required this.user,
    required this.addedAt,
    required this.lastUsedAt,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    userId: json['userId'] as int,
    token: json['token'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    lastUsedAt: (json['lastUsedAt'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'token': token,
    'user': user.toJson(),
    'addedAt': addedAt,
    'lastUsedAt': lastUsedAt,
  };

  SavedAccount copyWith({
    String? token,
    AuthUser? user,
    int? addedAt,
    int? lastUsedAt,
  }) => SavedAccount(
    userId: userId,
    token: token ?? this.token,
    user: user ?? this.user,
    addedAt: addedAt ?? this.addedAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
}

/// Wrapper `SharedPreferences` untuk daftar akun & identitas perangkat.
class AccountStore {
  AccountStore._();

  static final AccountStore instance = AccountStore._();

  /// Batas akun tersimpan; entri paling lama tidak dipakai dibuang.
  static const maxAccounts = 5;

  static const _accountsKey = 'saved_accounts';
  static const _activeKey = 'active_account_id';
  static const _deviceIdKey = 'device_id';

  // Key sesi versi lama — dibaca sekali oleh [migrateLegacy] lalu dihapus.
  static const _legacyTokenKey = 'auth_token';
  static const _legacyUserKey = 'auth_user';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Daftar akun tersimpan, terbaru di posisi 0.
  Future<List<SavedAccount>> readAccounts() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedAccount.fromJson)
          .toList();
    } catch (_) {
      // Data rusak/versi lama: anggap belum ada akun tersimpan.
      return [];
    }
  }

  /// ID akun yang sedang aktif (`null` bila belum ada).
  Future<int?> readActiveId() async {
    final prefs = await _prefs;
    return prefs.getInt(_activeKey);
  }

  /// Akun yang sedang aktif, atau `null` bila tidak ada / datanya hilang.
  Future<SavedAccount?> readActive() async {
    final id = await readActiveId();
    if (id == null) return null;
    final accounts = await readAccounts();
    for (final account in accounts) {
      if (account.userId == id) return account;
    }
    return null;
  }

  /// Simpan/perbarui akun: dedupe berdasarkan [SavedAccount.userId],
  /// sisip di posisi 0, dan buang entri paling lama bila melewati batas.
  Future<void> upsert(SavedAccount account) async {
    final prefs = await _prefs;
    final accounts = await readAccounts();

    SavedAccount? existing;
    for (final item in accounts) {
      if (item.userId == account.userId) {
        existing = item;
        break;
      }
    }
    accounts.removeWhere((item) => item.userId == account.userId);

    accounts.insert(
      0,
      account.copyWith(addedAt: existing?.addedAt ?? account.addedAt),
    );

    if (accounts.length > maxAccounts) {
      final excess = accounts.length - maxAccounts;
      // Buang yang paling lama tidak dipakai; tie-break pakai waktu
      // ditambahkan supaya hasilnya deterministik.
      final removable = [...accounts]
        ..sort((a, b) {
          final byUse = a.lastUsedAt.compareTo(b.lastUsedAt);
          return byUse != 0 ? byUse : a.addedAt.compareTo(b.addedAt);
        });
      final ids = removable.take(excess).map((a) => a.userId).toSet();
      accounts.removeWhere((a) => ids.contains(a.userId));
    }

    await _writeAccounts(prefs, accounts);
  }

  /// Hapus satu akun. Bila akun itu sedang aktif, status aktif dikosongkan.
  Future<void> remove(int userId) async {
    final prefs = await _prefs;
    final accounts = await readAccounts();
    accounts.removeWhere((account) => account.userId == userId);
    await _writeAccounts(prefs, accounts);

    if (prefs.getInt(_activeKey) == userId) {
      await prefs.remove(_activeKey);
    }
  }

  /// Tandai akun aktif (`null` = tidak ada akun aktif).
  Future<void> setActive(int? userId) async {
    final prefs = await _prefs;
    if (userId == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setInt(_activeKey, userId);
    }
  }

  /// Hapus semua akun tersimpan. `device_id` sengaja dipertahankan agar
  /// perangkat ini tetap dikenali server setelah logout total.
  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_accountsKey);
    await prefs.remove(_activeKey);
  }

  /// ID perangkat stabil: dibuat sekali lalu dipakai ulang, sehingga
  /// login di perangkat ini hanya mengganti token perangkat ini.
  Future<String> deviceId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random();
    final suffix = random
        .nextInt(1 << 32)
        .toRadixString(16)
        .padLeft(8, '0');
    final id =
        'dev-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$suffix';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  /// Migrasi sesi tunggal versi lama (`auth_token` + `auth_user`) menjadi
  /// akun pertama. Dipanggil sekali di `main()` supaya user yang sudah
  /// login tidak ter-logout setelah update.
  Future<void> migrateLegacy() async {
    final prefs = await _prefs;
    final token = prefs.getString(_legacyTokenKey);
    final rawUser = prefs.getString(_legacyUserKey);

    if (token != null && rawUser != null) {
      try {
        final user = AuthUser.fromJson(
          jsonDecode(rawUser) as Map<String, dynamic>,
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        await upsert(
          SavedAccount(
            userId: user.id,
            token: token,
            user: user,
            addedAt: now,
            lastUsedAt: now,
          ),
        );
        await setActive(user.id);
      } catch (_) {
        // Data lama rusak: abaikan, user cukup login ulang.
      }
    }

    // Key lama tidak dipakai lagi setelah migrasi (juga saat migrasi gagal,
    // supaya tidak dicoba berulang tiap app dibuka).
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyUserKey);
    await TokenStorage.removeLegacyPassword();
  }

  Future<void> _writeAccounts(
    SharedPreferences prefs,
    List<SavedAccount> accounts,
  ) async {
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }
}