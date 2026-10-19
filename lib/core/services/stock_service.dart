/// Service stok: komunikasi dengan endpoint `/products/stock` dan
/// `/components/stock`.
library;

import '../data/models.dart';
import '../network/api_client.dart';

class StockService {
  StockService._();

  static final StockService instance = StockService._();

  final ApiClient _client = ApiClient.instance;

  /// Ambil daftar stok produk untuk [outletId].
  ///
  /// [withDetail] = `true` akan meminta rincian komponen penyusun
  /// tiap produk (query `detail=1` di backend).
  Future<List<ProductStock>> fetchProductStock(
    int outletId, {
    bool withDetail = false,
  }) async {
    final body = await _client.get(
      '/products/stock',
      query: {'outlet_id': outletId, if (withDetail) 'detail': '1'},
    );

    final data = (body as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => ProductStock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ambil daftar stok bahan/komponen untuk [outletId].
  Future<List<ComponentStock>> fetchComponentStock(int outletId) async {
    final body = await _client.get(
      '/components/stock',
      query: {'outlet_id': outletId},
    );

    final data = (body as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => ComponentStock.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
