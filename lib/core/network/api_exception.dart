/// Exception standar untuk kegagalan pemanggilan API.
library;

/// Error yang dilempar [ApiClient] ketika request gagal.
///
/// [message] diambil dari field `message` pada respon JSON backend
/// sehingga siap ditampilkan langsung ke pengguna.
class ApiException implements Exception {
  final String message;

  /// Kode status HTTP, `null` jika error terjadi sebelum response
  /// (misalnya timeout atau server tidak bisa dijangkau).
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
