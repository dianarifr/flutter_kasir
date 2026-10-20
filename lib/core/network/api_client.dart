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

  /// Callback saat sesi hangus (401 pada request yang membawa token).
  /// Dipasang sekali di main.dart: membersihkan sesi lokal lalu
  /// mengarahkan user ke halaman login.
  void Function()? onUnauthorized;

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
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final hadAuth = _token != null;
    final response = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handle(response, hadAuth: hadAuth);
  }

  /// POST request dengan body JSON.
  Future<dynamic> post(String path, {Object? body}) async {
    final hadAuth = _token != null;
    final response = await _client
        .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(ApiConfig.timeout);
    return _handle(response, hadAuth: hadAuth);
  }

  dynamic _handle(http.Response response, {required bool hadAuth}) {
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

    if (response.statusCode == 401) {
      // 401 pada request TANPA token berarti login ditolak (email/password
      // salah) — pesan backend dipakai apa adanya, bukan sesi hangus.
      if (hadAuth) {
        // Token invalid/kadaluarsa; hapus sesi lokal.
        _token = null;
        message = 'Sesi berakhir, silakan login kembali.';

        if (!_isNotifyingUnauthorized) {
          _isNotifyingUnauthorized = true;
          onUnauthorized?.call();
          // Buka kunci setelah jeda — beberapa request paralel bisa 401
          // bersamaan dan cukup sekali mengarahkan ke halaman login.
          Future<void>.delayed(const Duration(seconds: 2))
              .then((_) => _isNotifyingUnauthorized = false);
        }
      }
    }

    throw ApiException(message, statusCode: response.statusCode);
  }
}
