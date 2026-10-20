/// Service charge: komunikasi dengan endpoint `/charges` (master charge
/// aktif untuk toggle dinamis di halaman checkout).
library;

import '../data/models.dart';
import '../network/api_client.dart';

class ChargeService {
  ChargeService._();

  static final ChargeService instance = ChargeService._();

  final ApiClient _client = ApiClient.instance;

  /// Ambil daftar charge aktif (pajak, diskon, dll).
  Future<List<MasterCharge>> fetchCharges() async {
    final body = await _client.get('/charges');

    final data = (body as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => MasterCharge.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
