/// Service shift kasir: endpoint `/shifts/current` (shift aktif + live
/// ringkasan), `/shifts/open` (buka shift dengan modal awal), dan
/// `/shifts/{id}/close` (tombol "Setor" = tutup shift).
library;

import '../data/models.dart';
import '../network/api_client.dart';

class ShiftService {
  ShiftService._();

  static final ShiftService instance = ShiftService._();

  final ApiClient _client = ApiClient.instance;

  /// Shift aktif milik user yang sedang login.
  /// Mengembalikan `null` bila belum ada shift yang dibuka.
  Future<Shift?> fetchCurrent() async {
    final body = await _client.get('/shifts/current');
    final data = (body as Map<String, dynamic>)['data'];
    if (data == null) return null;

    return Shift.fromJson(data as Map<String, dynamic>);
  }

  /// Buka shift baru dengan modal awal dari input kasir.
  /// Backend menolak (409) bila masih ada shift yang belum ditutup.
  Future<Shift> open(int startingCash) async {
    final body = await _client.post(
      '/shifts/open',
      body: {'starting_cash': startingCash},
    );

    final data = (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return Shift.fromJson(data);
  }

  /// Tutup shift (setor): uang disetor + catatan opsional. Selisih
  /// terhadap perkiraan isi laci dihitung backend dan ikut di-response.
  Future<Shift> close(int shiftId, int endingCash, String? notes) async {
    final trimmed = notes?.trim() ?? '';
    final body = await _client.post('/shifts/$shiftId/close', body: {
      'ending_cash': endingCash,
      if (trimmed.isNotEmpty) 'notes': trimmed,
    });

    final data = (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return Shift.fromJson(data);
  }
}
