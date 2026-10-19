import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'models.dart';
import '../network/api_exception.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/stock_service.dart';

/// State global in-memory yang dipakai lintas halaman.
/// Halaman yang butuh reaktif memakai [ListenableBuilder] dengan [instance].
///
/// Data sesi (user/outlet) dan stok produk diambil dari API backend,
/// sedangkan data dummy lama tetap dipakai halaman yang belum diintegrasikan.
class AppData extends ChangeNotifier {
  AppData._() {
    _seedOrders();
  }

  static final AppData instance = AppData._();

  // ---- Konstanta checkout ----
  static const double discountRate = 0.10;
  static const int extraFeeAmount = 2000;

  // ---- Sesi & data dari API ----
  AuthUser? _currentUser;
  List<ProductStock> _productStocks = [];
  bool _isLoadingStock = false;
  String? _stockError;
  List<ComponentStock> _componentStocks = [];
  bool _isLoadingComponents = false;
  String? _componentError;

  /// User yang sedang login (`null` sebelum login).
  AuthUser? get currentUser => _currentUser;

  /// Outlet tempat user bertugas (`null` jika belum login / admin).
  Outlet? get currentOutlet => _currentUser?.outlet;

  /// Daftar stok produk pada outlet saat ini (dari API).
  List<ProductStock> get productStocks => List.unmodifiable(_productStocks);

  bool get isLoadingStock => _isLoadingStock;

  /// Pesan error terakhir saat memuat stok (`null` = tidak ada error).
  String? get stockError => _stockError;

  /// Daftar stok bahan/komponen pada outlet saat ini (dari API).
  List<ComponentStock> get componentStocks =>
      List.unmodifiable(_componentStocks);

  bool get isLoadingComponents => _isLoadingComponents;

  /// Pesan error terakhir saat memuat stok bahan (`null` = tidak ada error).
  String? get componentError => _componentError;

  /// Simpan sesi user setelah login / auto-login.
  void setSession(AuthUser user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Muat stok produk dari API untuk outlet user yang sedang login.
  ///
  /// [withDetail] = `true` menyertakan rincian komponen per produk.
  Future<void> loadProductStock({bool withDetail = false}) async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _stockError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingStock = true;
    _stockError = null;
    notifyListeners();

    try {
      _productStocks = await StockService.instance.fetchProductStock(
        outlet.id,
        withDetail: withDetail,
      );
    } on ApiException catch (e) {
      _stockError = e.message;
    } catch (_) {
      _stockError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingStock = false;
      notifyListeners();
    }
  }

  /// Muat stok bahan/komponen dari API untuk outlet user yang sedang login.
  Future<void> loadComponentStock() async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _componentError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingComponents = true;
    _componentError = null;
    notifyListeners();

    try {
      _componentStocks = await StockService.instance.fetchComponentStock(
        outlet.id,
      );
    } on ApiException catch (e) {
      _componentError = e.message;
    } catch (_) {
      _componentError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingComponents = false;
      notifyListeners();
    }
  }

  /// Logout: hapus token di backend & bersihkan state sesi.
  ///
  /// Gagal request ke backend (server mati / token sudah hangus / 401)
  /// TIDAK boleh menggagalkan logout — sesi lokal tetap dibersihkan
  /// supaya app kembali ke halaman login.
  Future<void> logout() async {
    try {
      await AuthService.instance.logout();
    } catch (_) {
      // Abaikan error API; pembersihan lokal sudah dilakukan di
      // AuthService.logout (finally).
    }
    _currentUser = null;
    _productStocks = [];
    _stockError = null;
    _componentStocks = [];
    _componentError = null;
    _products = [];
    _productsError = null;
    notifyListeners();
  }

  // ---- Data dari API: produk untuk menu kasir (POS) ----
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  String? _productsError;

  /// Daftar produk untuk menu kasir (dari API, TANPA info stok —
  /// semua produk tampil apa adanya).
  List<Product> get products => List.unmodifiable(_products);

  bool get isLoadingProducts => _isLoadingProducts;

  /// Pesan error terakhir saat memuat produk (`null` = tidak ada error).
  String? get productsError => _productsError;

  /// Muat daftar produk dari API untuk outlet user yang sedang login.
  Future<void> loadProducts() async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _productsError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingProducts = true;
    _productsError = null;
    notifyListeners();

    try {
      _products = await ProductService.instance.fetchProducts(outlet.id);
    } on ApiException catch (e) {
      _productsError = e.message;
    } catch (_) {
      _productsError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  // ---- Data dummy lainnya ----

  final List<StockItem> stockItems = [
    StockItem(
      id: 's1',
      name: 'Dimsum Besar',
      unit: 'pcs',
      stock: 12,
      minStock: 15,
    ),
    StockItem(
      id: 's2',
      name: 'Chili Oil',
      unit: 'botol',
      stock: 2,
      minStock: 5,
    ),
    StockItem(id: 's3', name: 'Keju Parut', unit: 'kg', stock: 3, minStock: 2),
    StockItem(
      id: 's4',
      name: 'Saus Mentai',
      unit: 'porsi',
      stock: 40,
      minStock: 20,
    ),
    StockItem(id: 's5', name: 'Es Batu', unit: 'kg', stock: 8, minStock: 5),
  ];

  final List<String> customers = const [
    'Temen mbak rista',
    'Mas Budi',
    'Mbak Ani',
  ];

  final Map<String, int> _cart = {};
  final List<Order> _orders = [];

  int _orderSeq = 14;
  int _queueSeq = 4;

  // ---- Getter ----
  List<Order> get orders => List.unmodifiable(_orders);

  UnmodifiableMapView<String, int> get cart => UnmodifiableMapView(_cart);

  int cartQty(String productId) => _cart[productId] ?? 0;

  int get cartItemCount => _cart.values.fold(0, (sum, qty) => sum + qty);

  int get cartSubtotal => _cart.entries.fold(0, (sum, entry) {
    final product = products.firstWhere(
      (p) => p.id == entry.key,
      orElse: () => const Product(id: '-', name: '-', price: 0),
    );
    return sum + product.price * entry.value;
  });

  List<Order> get paidOrders => _orders.where((o) => o.isPaid).toList();

  int get todayRevenue => paidOrders.fold(0, (sum, o) => sum + o.total);

  List<StockItem> get criticalStock =>
      stockItems.where((s) => s.isCritical).toList();

  List<Order> get recentOrders => _orders.reversed.take(4).toList();

  // ---- Keranjang ----
  void addToCart(String productId) {
    _cart[productId] = (_cart[productId] ?? 0) + 1;
    notifyListeners();
  }

  void decrementCart(String productId) {
    final qty = _cart[productId] ?? 0;
    if (qty <= 1) {
      _cart.remove(productId);
    } else {
      _cart[productId] = qty - 1;
    }
    notifyListeners();
  }

  void setCartQty(String productId, int qty) {
    if (qty <= 0) {
      _cart.remove(productId);
    } else {
      _cart[productId] = qty;
    }
    notifyListeners();
  }

  // ---- Pesanan ----
  String _nextOrderId() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final id =
        'DAV'
        '${two(now.day)}${two(now.month)}'
        '${now.year % 100}'
        '${two(now.hour)}${two(now.minute)}'
        '${two(_orderSeq)}';
    _orderSeq++;
    return id;
  }

  /// Membuat pesanan baru dari isi keranjang (status: Diproses, belum bayar),
  /// lalu mengosongkan keranjang.
  Order createOrder({
    String customer = '',
    required int discount,
    required int extraFee,
    Map<String, String> notes = const {},
  }) {
    final items = _cart.entries.map((entry) {
      final product = products.firstWhere((p) => p.id == entry.key);
      return OrderItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        qty: entry.value,
        note: notes[product.id] ?? '',
      );
    }).toList();

    final order = Order(
      id: _nextOrderId(),
      customer: customer,
      createdAt: DateTime.now(),
      queueNumber: _queueSeq++,
      items: items,
      subtotal: items.fold(0, (sum, item) => sum + item.subtotal),
      discount: discount,
      extraFee: extraFee,
      status: OrderStatus.diproses,
      isPaid: false,
    );

    _orders.add(order);
    _cart.clear();
    notifyListeners();
    return order;
  }

  void payOrder(
    Order order, {
    required PaymentMethod method,
    int cashGiven = 0,
    int changeGiven = 0,
    int splitCash = 0,
    int splitNonCash = 0,
    String customer = '',
  }) {
    order.isPaid = true;
    order.status = OrderStatus.selesai;
    order.paymentMethod = method;
    order.cashGiven = cashGiven;
    order.changeGiven = changeGiven;
    order.splitCash = splitCash;
    order.splitNonCash = splitNonCash;
    if (customer.isNotEmpty) order.customer = customer;
    notifyListeners();
  }

  void cancelOrder(Order order) {
    order.status = OrderStatus.dibatalkan;
    notifyListeners();
  }

  void completeOrder(Order order) {
    order.status = OrderStatus.selesai;
    notifyListeners();
  }

  // ---- Stok ----
  void adjustStock(StockItem item, int delta) {
    item.stock = (item.stock + delta).clamp(0, 999);
    notifyListeners();
  }

  // ---- Seed dummy ----
  Order _seedOrder({
    required String id,
    required String customer,
    required Duration ago,
    required int queueNumber,
    required OrderStatus status,
    required bool isPaid,
    required List<OrderItem> items,
    PaymentMethod? paymentMethod,
    int cashGiven = 0,
    int changeGiven = 0,
  }) {
    return Order(
      id: id,
      customer: customer,
      createdAt: DateTime.now().subtract(ago),
      queueNumber: queueNumber,
      items: items,
      subtotal: items.fold(0, (sum, item) => sum + item.subtotal),
      status: status,
      isPaid: isPaid,
      paymentMethod: paymentMethod,
      cashGiven: cashGiven,
      changeGiven: changeGiven,
    );
  }

  void _seedOrders() {
    _orders.add(
      _seedOrder(
        id: 'DAV06260682211',
        customer: 'Temen mbak rista',
        ago: const Duration(hours: 2, minutes: 10),
        queueNumber: 1,
        status: OrderStatus.diproses,
        isPaid: false,
        items: const [
          OrderItem(
            productId: '5',
            name: 'Dimsum mentai isi 4',
            price: 18000,
            qty: 1,
          ),
          OrderItem(
            productId: '4',
            name: 'Dimsum bakar ori',
            price: 17000,
            qty: 1,
          ),
          OrderItem(productId: '7', name: 'Degan', price: 12000, qty: 1),
          OrderItem(productId: '8', name: 'Coklat', price: 12000, qty: 1),
        ],
      ),
    );

    _orders.add(
      _seedOrder(
        id: 'DAV06260682212',
        customer: 'Mas Budi',
        ago: const Duration(hours: 2, minutes: 40),
        queueNumber: 2,
        status: OrderStatus.selesai,
        isPaid: true,
        paymentMethod: PaymentMethod.tunai,
        cashGiven: 40000,
        changeGiven: 2000,
        items: const [
          OrderItem(
            productId: '1',
            name: 'Dimsum bakar keju',
            price: 19000,
            qty: 2,
          ),
        ],
      ),
    );

    _orders.add(
      _seedOrder(
        id: 'DAV06260682213',
        customer: 'Mbak Ani',
        ago: const Duration(hours: 3, minutes: 55),
        queueNumber: 3,
        status: OrderStatus.dibatalkan,
        isPaid: false,
        items: const [
          OrderItem(
            productId: '2',
            name: 'Dimsum bakar mentai',
            price: 20000,
            qty: 1,
          ),
        ],
      ),
    );
  }
}
