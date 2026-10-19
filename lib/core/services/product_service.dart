/// Service produk: komunikasi dengan endpoint `/products` (menu kasir/POS).
library;

import '../data/models.dart';
import '../network/api_client.dart';

class ProductService {
  ProductService._();

  static final ProductService instance = ProductService._();

  final ApiClient _client = ApiClient.instance;

  /// Ambil daftar semua produk untuk [outletId].
  ///
  /// Backend mengembalikan semua produk TANPA info stok (kasir boleh
  /// menjual apa saja), harga diambil dari `outlet_prices` per outlet,
  /// dan `image_url` berisi URL absolut gambar produk (bisa null).
  Future<List<Product>> fetchProducts(int outletId) async {
    final body = await _client.get('/products', query: {'outlet_id': outletId});

    final data = (body as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
