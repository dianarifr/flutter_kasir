/// Service order: komunikasi dengan endpoint `/orders` (transaksi kasir).
///
/// Alur sesuai backend:
/// - [createOrder]      : POST /orders — simpan order (status diproses, belum bayar).
/// - [payOrder]         : POST /orders/{id}/pay — bayar tunai/non tunai/campuran.
/// - [cancelOrder]      : POST /orders/{id}/cancel — batalkan + stok dikembalikan.
/// - [fetchOrders]      : GET /orders — daftar order hari ini.
/// - [fetchCustomers]   : GET /orders/customers — nama pelanggan (10 terbaru).
library;

import '../data/models.dart';
import '../network/api_client.dart';

/// Hasil [OrderService.createOrder]: order baru + peringatan bahan
/// yang jadi habis/minus (kosong bila tidak ada).
class CreateOrderResult {
  final Order order;
  final List<StockWarning> warnings;

  const CreateOrderResult({required this.order, this.warnings = const []});
}

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  final ApiClient _client = ApiClient.instance;

  /// Simpan order baru dari isi keranjang.
  ///
  /// [items] berupa map siap kirim: `{product_id, qty, note?}`.
  /// [chargeIds] = id master charge yang diaktifkan kasir di checkout.
  Future<CreateOrderResult> createOrder({
    required List<Map<String, dynamic>> items,
    String? customerName,
    List<int> chargeIds = const [],
  }) async {
    final body = await _client.post(
      '/orders',
      body: {
        'items': items,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (chargeIds.isNotEmpty) 'charge_ids': chargeIds,
      },
    );

    final json = body as Map<String, dynamic>;
    final order = Order.fromJson(json['data'] as Map<String, dynamic>);
    final warnings = (json['warnings'] as List<dynamic>? ?? const [])
        .map((e) => StockWarning.fromJson(e as Map<String, dynamic>))
        .toList();

    return CreateOrderResult(order: order, warnings: warnings);
  }

  /// Bayar sebuah order.
  ///
  /// [method] salah satu: `tunai`, `non_tunai`, `campuran`.
  /// - tunai    : wajib [cashGiven] (kembalian dihitung backend).
  /// - campuran : wajib [splitCash] + [splitNonCash] >= total.
  Future<Order> payOrder(
    int orderId, {
    required String method,
    double? cashGiven,
    double? splitCash,
    double? splitNonCash,
  }) async {
    final body = await _client.post(
      '/orders/$orderId/pay',
      body: {
        'payment_method': method,
        'cash_given': ?cashGiven,
        'split_cash': ?splitCash,
        'split_non_cash': ?splitNonCash,
      },
    );

    return Order.fromJson(
      (body as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Batalkan order (stok bahan dikembalikan oleh backend).
  /// Backend menolak batal untuk order yang sudah dibayar.
  Future<Order> cancelOrder(int orderId) async {
    final body = await _client.post('/orders/$orderId/cancel');
    return Order.fromJson(
      (body as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Daftar nama pelanggan (maksimal 10 terbaru) untuk autocomplete
  /// di checkout — diambil dari distinct customer_name order.
  Future<List<String>> fetchCustomers(int outletId) async {
    final body = await _client.get(
      '/orders/customers',
      query: {'outlet_id': outletId},
    );

    final data = (body as Map<String, dynamic>)['data'] as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  /// Daftar order pada [outletId] (default: hari ini).
  ///
  /// [status] optional: `diproses` | `selesai` | `dibatalkan`.
  Future<List<Order>> fetchOrders(
    int outletId, {
    String? status,
    DateTime? date,
  }) async {
    final body = await _client.get(
      '/orders',
      query: {
        'outlet_id': outletId,
        'status': ?status,
        if (date != null) 'date': _formatDate(date),
      },
    );

    final data = (body as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Format tanggal YYYY-MM-DD untuk query parameter.
  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
