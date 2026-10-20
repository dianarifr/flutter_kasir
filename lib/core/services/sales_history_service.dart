/// Service riwayat penjualan: endpoint `/sales-history` (rekap per
/// periode untuk menu "Riwayat Penjualan" + detail produk terjual).
library;

import '../data/models.dart';
import '../network/api_client.dart';

class SalesHistoryService {
  SalesHistoryService._();

  static final SalesHistoryService instance = SalesHistoryService._();

  final ApiClient _client = ApiClient.instance;

  /// Rekap + daftar transaksi lunas sesuai [filter] periode.
  Future<SalesHistory> fetch(SalesFilter filter) async {
    final body = await _client.get('/sales-history', query: filter.toQuery());

    final data = (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return SalesHistory.fromJson(data);
  }

  /// Detail produk terjual (agregasi per produk) untuk periode yang sama.
  Future<List<ProductSold>> fetchProducts(SalesFilter filter) async {
    final body = await _client.get(
      '/sales-history/products',
      query: filter.toQuery(),
    );

    final data = (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final list = data['products'] as List<dynamic>? ?? [];

    return list
        .map((e) => ProductSold.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
