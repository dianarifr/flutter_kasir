/// Service autentikasi: komunikasi dengan endpoint login/logout API.
library;

import '../data/models.dart';
import '../network/api_client.dart';
import 'token_storage.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final ApiClient _client = ApiClient.instance;

  /// Login ke backend, simpan token + data user, lalu kembalikan user.
  ///
  /// [deviceName] wajib oleh backend (mis. "Samsung A54"); default
  /// diisi dari platform agar memenuhi validasi tanpa package tambahan.
  ///
  /// [remember] = `true` menyimpan sesi ke penyimpanan lokal agar
  /// app berikutnya langsung auto-login. `false` = sesi hanya hidup
  /// selama app berjalan (token di memori saja, tidak disimpan).
  Future<AuthUser> login({
    required String email,
    required String password,
    String deviceName = 'Flutter App',
    bool remember = true,
  }) async {
    final body = await _client.post(
      '/login',
      body: {'email': email, 'password': password, 'device_name': deviceName},
    );

    final data = (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

    // Terapkan token ke client agar langsung bisa dipakai sesi ini.
    _client.setToken(token);

    // Simpan kredensial utk fitur "Ingat saya" (tetap prefill di login page
    // setelah logout; ikut menghapus kredensial lama bila remember = false).
    await TokenStorage.saveCredentials(
      email: email,
      password: password,
      remember: remember,
    );

    if (remember) {
      // Simpan sesi secara lokal (auto-login saat app dibuka lagi).
      await TokenStorage.saveToken(token);
      await TokenStorage.saveUser(data['user'] as Map<String, dynamic>);
    } else {
      // Pastikan tidak ada sesi lama yang tersisa di penyimpanan.
      await TokenStorage.clear();
    }

    return user;
  }

  /// Logout di backend (hapus token) lalu bersihkan sesi lokal.
  Future<void> logout() async {
    try {
      await _client.post('/logout');
    } finally {
      // Sesi lokal tetap dibersihkan walau request logout gagal.
      _client.setToken(null);
      await TokenStorage.clear();
    }
  }

  /// Bersihkan sesi lokal TANPA memanggil API logout — dipakai saat
  /// sesi hangus (401): token sudah tidak valid, request logout hanya
  /// akan 401 lagi. Kredensial "Ingat saya" tetap dipertahankan.
  Future<void> clearLocalSession() async {
    _client.setToken(null);
    await TokenStorage.clear();
  }

  /// Muat sesi tersimpan (token + user) untuk auto-login.
  ///
  /// Mengembalikan user yang tersimpan, atau `null` jika belum login.
  /// Token otomatis diterapkan ke [ApiClient].
  Future<AuthUser?> restoreSession() async {
    final token = await TokenStorage.readToken();
    if (token == null) return null;

    _client.setToken(token);
    final stored = await TokenStorage.readUser();
    if (stored == null) return null;

    return AuthUser.fromJson(stored);
  }
}
