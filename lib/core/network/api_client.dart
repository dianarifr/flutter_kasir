/// HTTP client terpusat untuk semua pemanggilan API backend.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

/// Wrapper ringan di atas package `http`.
///
/// Tanggung jawab:
/// - Menyusun URL lengkap dari [ApiConfig.baseUrl].
/// - Menyertakan header standar (Accept + Bearer token).
/// - Mem-parsing envelope JSON backend `{status, message, data}`.
/// - Menerjemahkan kegagalan HTTP menjadi [ApiException].
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  http.Client _client = http.Client();

  /// Token yang sedang dipakai; diisi oleh [AuthService] setelah login.
  String? _token;

  /// Digunakan untuk pengujian (injeksi mock client).
  @visibleForTesting
  void setClient(http.Client client) {
    _client.close();
    _client = client;
  }

  void setToken(String? token) => _token = token;

  /// Token yang sedang dipakai (dipakai [AuthService] untuk memulihkan
  /// token sebelumnya saat ganti akun gagal).
  String? get token => _token;

  /// Callback saat sesi hangus (401 pada request yang membawa token).
  /// Dipasang sekali di main.dart.
  ///
  /// `true`  = sudah ditangani (mis. pindah ke akun lain tersimpan),
  /// `false` = tidak ada akun lain; app harus ke halaman login.
  Future<bool> Function()? onUnauthorized;

  /// Penanda agar banyak request yang 401 hampir bersamaan hanya
  /// memicu satu kali callback — satu redirect, bukan bertubi-tubi.
  bool _isNotifyingUnauthorized = false;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('${ApiConfig.baseUrl}/$normalized').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }

  /// GET request; mengembalikan body JSON yang sudah di-decode.
  ///
  /// [notifyOnUnauthorized] = `false` untuk request yang menangani 401
  /// sendiri (mis. validasi token saat ganti akun) agar tidak memicu
  /// pembersihan akun aktif.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool notifyOnUnauthorized = true,
  }) async {
    final sentToken = _token;
    final response = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handle(
      response,
      sentToken: sentToken,
      notifyOnUnauthorized: notifyOnUnauthorized,
    );
  }

  /// POST request dengan body JSON.
  Future<dynamic> post(
    String path, {
    Object? body,
    bool notifyOnUnauthorized = true,
  }) async {
    final sentToken = _token;
    final response = await _client
        .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.timeout);
    return _handle(
      response,
      sentToken: sentToken,
      notifyOnUnauthorized: notifyOnUnauthorized,
    );
  }

  /// PUT request dengan body JSON (dipakai simpan pengaturan yang
  /// idempoten, mis. teks penutup struk per outlet).
  Future<dynamic> put(
    String path, {
    Object? body,
    bool notifyOnUnauthorized = true,
  }) async {
    final sentToken = _token;
    final response = await _client
        .put(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.timeout);
    return _handle(
      response,
      sentToken: sentToken,
      notifyOnUnauthorized: notifyOnUnauthorized,
    );
  }

  /// DELETE request (dipakai hapus item order).
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? query,
    bool notifyOnUnauthorized = true,
  }) async {
    final sentToken = _token;
    final response = await _client
        .delete(_uri(path, query), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handle(
      response,
      sentToken: sentToken,
      notifyOnUnauthorized: notifyOnUnauthorized,
    );
  }

  Future<dynamic> _handle(
    http.Response response, {
    required String? sentToken,
    bool notifyOnUnauthorized = true,
  }) async {
    final hadAuth = sentToken != null;
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // Ambil pesan dari respon backend jika ada, fallback ke pesan umum.
    String message = 'Terjadi kesalahan pada server.';
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] is String) message = decoded['message'] as String;
      // Gabungkan detail validasi (Laravel: errors.{field}[])
      final errors = decoded['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final details = errors.values
            .expand((e) => e is List ? e : [e])
            .join('\n');
        if (details.isNotEmpty) message = details;
      }
    }

    if (response.statusCode == 401 && hadAuth && notifyOnUnauthorized) {
      // 401 pada request TANPA token berarti login ditolak (email/password
      // salah) — pesan backend dipakai apa adanya, bukan sesi hangus.
      //
      // Respons bisa datang terlambat, setelah akun sudah berganti:
      // hanya tangani bila token yang dipakai masih token aktif. Kalau
      // tidak, jangan hapus token akun baru.
      if (_token != sentToken) {
        throw ApiException(message, statusCode: response.statusCode);
      }

      // Token invalid/kadaluarsa; hapus sesi lokal.
      _token = null;
      message = 'Sesi berakhir, silakan login kembali.';

      if (!_isNotifyingUnauthorized) {
        _isNotifyingUnauthorized = true;
        try {
          await onUnauthorized?.call();
        } catch (_) {
          // Kegagalan handler tidak boleh menutupi error 401 asli.
        } finally {
          // Buka kunci setelah jeda — beberapa request paralel bisa 401
          // bersamaan dan cukup sekali menangani sesi hangus.
          Future<void>.delayed(const Duration(seconds: 2))
              .then((_) => _isNotifyingUnauthorized = false);
        }
      }
    }

    throw ApiException(message, statusCode: response.statusCode);
  }
}
