import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'models.dart';
import '../network/api_exception.dart';
import '../services/auth_service.dart';
import '../services/charge_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/sales_history_service.dart';
import '../services/shift_service.dart';
import '../services/stock_service.dart';

/// State global in-memory yang dipakai lintas halaman.
/// Halaman yang butuh reaktif memakai [ListenableBuilder] dengan [instance].
///
/// Semua data (sesi, produk, stok, charge, order) diambil dari API backend.
class AppData extends ChangeNotifier {
  AppData._();

  static final AppData instance = AppData._();

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
  ///
  /// Data milik user/outlet sebelumnya ikut dibuang (defensif — logout
  /// juga sudah membersihkan) supaya tidak ada angka lintas outlet yang
  /// tersisa bila ganti akun dalam satu sesi app.
  void setSession(AuthUser user) {
    _currentUser = user;
    _productStocks = [];
    _stockError = null;
    _componentStocks = [];
    _componentError = null;
    _products = [];
    _productsError = null;
    _charges = [];
    _orders = [];
    _customers = [];
    _salesHistory = null;
    _salesFilter = null;
    _productSales = [];
    _currentShift = null;
    _cart.clear();
    notifyListeners();
  }

  /// Muat stok produk dari API untuk outlet user yang sedang login.
  ///
  /// [withDetail] = `true` menyertakan rincian komponen per produk —
  /// dibutuhkan halaman POS untuk memperingatkan bahan yang kurang.
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

  /// Muat ulang kedua jenis stok sekaligus (dipakai setelah transaksi
  /// supaya angka stok di UI langsung berkurang/berubah).
  Future<void> reloadStocks() async {
    await Future.wait([
      loadProductStock(withDetail: true),
      loadComponentStock(),
    ]);
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
    await clearSessionLocal();
  }

  /// Bersihkan sesi & seluruh data TANPA memanggil API logout backend.
  ///
  /// Dipakai saat sesi hangus di tengah pemakaian (401): token sudah
  /// tidak valid sehingga request logout hanya akan 401 lagi.
  Future<void> clearSessionLocal() async {
    await AuthService.instance.clearLocalSession();
    _currentUser = null;
    _productStocks = [];
    _stockError = null;
    _componentStocks = [];
    _componentError = null;
    _products = [];
    _productsError = null;
    _charges = [];
    _orders = [];
    _customers = [];
    _salesHistory = null;
    _salesFilter = null;
    _productSales = [];
    _currentShift = null;
    _cart.clear();
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

  // ---- Data dari API: master charge (toggle checkout) ----
  List<MasterCharge> _charges = [];
  bool _isLoadingCharges = false;
  String? _chargesError;

  /// Daftar charge aktif (pajak, diskon, dll) dari backend.
  List<MasterCharge> get charges => List.unmodifiable(_charges);

  bool get isLoadingCharges => _isLoadingCharges;

  String? get chargesError => _chargesError;

  /// Muat daftar charge aktif (sekali muat, dipakai ulang).
  Future<void> loadCharges({bool force = false}) async {
    if (_charges.isNotEmpty && !force) return;

    _isLoadingCharges = true;
    _chargesError = null;
    notifyListeners();

    try {
      _charges = await ChargeService.instance.fetchCharges();
    } on ApiException catch (e) {
      _chargesError = e.message;
    } catch (_) {
      _chargesError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingCharges = false;
      notifyListeners();
    }
  }

  // ---- Data dari API: orders (transaksi kasir) ----
  List<Order> _orders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;

  /// Daftar order hari ini pada outlet saat ini (dari API).
  List<Order> get orders => List.unmodifiable(_orders);

  bool get isLoadingOrders => _isLoadingOrders;

  String? get ordersError => _ordersError;

  /// Muat daftar order dari API untuk outlet user yang sedang login.
  Future<void> loadOrders() async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _ordersError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingOrders = true;
    _ordersError = null;
    notifyListeners();

    try {
      _orders = await OrderService.instance.fetchOrders(outlet.id);
    } on ApiException catch (e) {
      _ordersError = e.message;
    } catch (_) {
      _ordersError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  /// Ganti order lama dengan versi terbaru dari backend (berdasarkan id).
  void _replaceOrder(Order updated) {
    final index = _orders.indexWhere((o) => o.id == updated.id);
    if (index >= 0) {
      _orders[index] = updated;
    } else {
      _orders.insert(0, updated);
    }
    notifyListeners();
  }

  // ---- Data dari API: pelanggan (untuk autocomplete checkout) ----
  List<String> _customers = [];
  bool _isLoadingCustomers = false;
  String? _customersError;

  /// Nama-nama pelanggan dari order sebelumnya (10 terbaru, dari API).
  List<String> get customers => List.unmodifiable(_customers);

  bool get isLoadingCustomers => _isLoadingCustomers;

  String? get customersError => _customersError;

  /// Muat daftar pelanggan dari API (distinct customer_name, 10 terbaru).
  Future<void> loadCustomers() async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _customersError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingCustomers = true;
    _customersError = null;
    notifyListeners();

    try {
      _customers = await OrderService.instance.fetchCustomers(outlet.id);
    } on ApiException catch (e) {
      _customersError = e.message;
    } catch (_) {
      _customersError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingCustomers = false;
      notifyListeners();
    }
  }

  // ---- Data dari API: riwayat penjualan (rekap per periode) ----
  SalesHistory? _salesHistory;
  SalesFilter? _salesFilter;
  bool _isLoadingSales = false;
  String? _salesError;

  /// Hasil terakhir GET /sales-history (`null` sebelum pernah dimuat).
  SalesHistory? get salesHistory => _salesHistory;

  /// Filter terakhir yang dipakai — dipakai ulang saat refresh & untuk
  /// halaman detail produk terjual.
  SalesFilter? get salesFilter => _salesFilter;

  bool get isLoadingSales => _isLoadingSales;

  String? get salesError => _salesError;

  /// Muat riwayat penjualan sesuai [filter] periode.
  Future<void> loadSalesHistory(SalesFilter filter) async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _salesError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingSales = true;
    _salesError = null;
    notifyListeners();

    try {
      _salesHistory = await SalesHistoryService.instance.fetch(filter);
      _salesFilter = filter;
    } on ApiException catch (e) {
      _salesError = e.message;
    } catch (_) {
      _salesError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingSales = false;
      notifyListeners();
    }
  }

  // ---- Data dari API: detail produk terjual (drill-down riwayat) ----
  List<ProductSold> _productSales = [];
  bool _isLoadingProductSales = false;
  String? _productSalesError;

  /// Daftar produk terjual (agregasi per produk) hasil muat terakhir.
  List<ProductSold> get productSales => List.unmodifiable(_productSales);

  bool get isLoadingProductSales => _isLoadingProductSales;

  String? get productSalesError => _productSalesError;

  /// Muat detail produk terjual sesuai [filter] periode.
  Future<void> loadProductSales(SalesFilter filter) async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _productSalesError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    _isLoadingProductSales = true;
    _productSalesError = null;
    notifyListeners();

    try {
      _productSales = await SalesHistoryService.instance.fetchProducts(filter);
    } on ApiException catch (e) {
      _productSalesError = e.message;
    } catch (_) {
      _productSalesError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingProductSales = false;
      notifyListeners();
    }
  }

  // ---- Shift kasir ----
  Shift? _currentShift;
  bool _isLoadingShift = false;

  /// Shift aktif milik user yang sedang login (`null` = belum buka
  /// shift). Kasir wajib buka shift sebelum bisa melayani transaksi.
  Shift? get currentShift => _currentShift;

  bool get isLoadingShift => _isLoadingShift;

  /// Muat shift aktif dari API — dipanggil saat masuk dashboard,
  /// pull-to-refresh, dan setelah pembayaran (angka ringkasan live).
  Future<void> loadCurrentShift() async {
    if (currentOutlet == null) {
      _currentShift = null;
      notifyListeners();
      return;
    }

    _isLoadingShift = true;
    notifyListeners();

    try {
      _currentShift = await ShiftService.instance.fetchCurrent();
    } catch (_) {
      // Gagal memuat (server mati dll): dianggap belum ada shift agar
      // kasir tetap diarahkan ke "Buka Shift"; bisa dicoba lagi.
      _currentShift = null;
    } finally {
      _isLoadingShift = false;
      notifyListeners();
    }
  }

  /// Buka shift baru dengan modal awal dari input kasir.
  /// Melempar [ApiException] bila backend menolak (mis. 409).
  Future<void> openShift(int startingCash) async {
    _currentShift = await ShiftService.instance.open(startingCash);
    notifyListeners();
  }

  /// Tutup shift (tombol "Setor"). Mengembalikan shift yang sudah
  /// ditutup (berisi ending_cash + selisih) untuk ditampilkan di UI.
  Future<Shift> closeShift(int endingCash, String? notes) async {
    final shift = _currentShift;
    if (shift == null) {
      throw StateError('Tidak ada shift aktif untuk ditutup.');
    }

    final closed = await ShiftService.instance.close(
      shift.id,
      endingCash,
      notes,
    );

    _currentShift = null;
    notifyListeners();
    return closed;
  }

  // ---- Keranjang ----

  final Map<String, int> _cart = {};

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

  /// Order yang lunas (dan tidak dibatalkan).
  List<Order> get paidOrders =>
      _orders.where((o) => o.isPaid && o.status != OrderStatus.dibatalkan).toList();

  /// Omzet dari order lunas yang dibuat hari ini.
  int get todayRevenue {
    final now = DateTime.now();
    return paidOrders
        .where(
          (o) =>
              o.createdAt.year == now.year &&
              o.createdAt.month == now.month &&
              o.createdAt.day == now.day,
        )
        .fold(0, (sum, o) => sum + o.total);
  }

  /// Bahan dengan stok <= ambang minimum (untuk kartu Stok Kritis).
  List<ComponentStock> get criticalStock =>
      _componentStocks.where((s) => s.isCritical).toList();

  List<Order> get recentOrders => _orders.take(4).toList();

  // ---- Peringatan stok (non-blocking) ----

  /// Cek bahan penyusun [productId] untuk [qty] porsi.
  ///
  /// Mengembalikan daftar teks peringatan ("Chili oil habis (sisa 0)");
  /// kosong bila semua bahan aman. TIDAK memblokir apa pun — kasir
  /// hanya diberi tahu. Butuh data stok produk dengan detail komponen.
  List<String> stockIssuesFor(String productId, int qty) {
    final issues = <String>[];
    final matches = _productStocks.where(
      (s) => s.id.toString() == productId,
    );
    if (matches.isEmpty) return issues;

    final stock = matches.first;
    if (!stock.isStockTracked) return issues;

    for (final component in stock.components) {
      final needed = component.qtyPerPortion * qty;
      if (needed <= 0) continue;

      if (component.currentStock <= 0) {
        issues.add('${component.componentName} habis (sisa 0)');
      } else if (component.currentStock < needed) {
        issues.add(
          '${component.componentName} kurang '
          '(sisa ${component.currentStock}, butuh $needed)',
        );
      }
    }
    return issues;
  }

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

  // ---- Transaksi (panggil API backend) ----

  /// Simpan order dari isi keranjang ke backend.
  ///
  /// Status awal: `diproses`, belum dibayar — dipakai baik untuk
  /// "Buat Pesanan" maupun "Bayar Langsung" (yang lanjut ke pembayaran).
  ///
  /// Mengembalikan [CreateOrderResult] berisi order + peringatan bahan
  /// habis/minus. Melempar [ApiException] bila gagal.
  Future<CreateOrderResult> createOrder({
    String customer = '',
    required Set<int> chargeIds,
    Map<String, String> notes = const {},
  }) async {
    final items = <Map<String, dynamic>>[];
    for (final entry in _cart.entries) {
      final matches = _products.where((p) => p.id == entry.key);
      if (matches.isEmpty) continue; // Produk sudah tidak ada di API — lewati.
      final product = matches.first;
      items.add({
        'product_id': int.parse(product.id),
        'qty': entry.value,
        if ((notes[product.id] ?? '').isNotEmpty) 'note': notes[product.id],
      });
    }

    final result = await OrderService.instance.createOrder(
      items: items,
      customerName: customer,
      chargeIds: chargeIds.toList(),
    );

    // Order baru paling atas; keranjang dikosongkan; stok dimuat ulang.
    _orders.insert(0, result.order);
    _cart.clear();
    notifyListeners();

    // Nama pelanggan yang baru diketik langsung masuk daftar (paling atas)
    // supaya muncul di picker pesanan berikutnya tanpa menunggu reload.
    final name = customer.trim();
    if (name.isNotEmpty) {
      _customers.remove(name);
      _customers.insert(0, name);
      if (_customers.length > 10) {
        _customers.removeRange(10, _customers.length);
      }
      notifyListeners();
    }

    // Stok bahan/produk berkurang karena transaksi — segarkan tanpa
    // menggagalkan proses utama bila gagal.
    unawaited(reloadStocks());

    return result;
  }

  /// Bayar [order] lewat backend, lalu perbarui data lokal.
  ///
  /// [method] salah satu dari `tunai` / `non_tunai` / `campuran`.
  Future<Order> payOrder(
    Order order, {
    required PaymentMethod method,
    int cashGiven = 0,
    int splitCash = 0,
    int splitNonCash = 0,
  }) async {
    final updated = await OrderService.instance.payOrder(
      int.parse(order.id),
      method: method.apiLabel,
      cashGiven: method == PaymentMethod.tunai && cashGiven > 0
          ? cashGiven.toDouble()
          : null,
      splitCash: method == PaymentMethod.campuran && splitCash > 0
          ? splitCash.toDouble()
          : null,
      splitNonCash: method == PaymentMethod.campuran && splitNonCash > 0
          ? splitNonCash.toDouble()
          : null,
    );

    _replaceOrder(updated);
    return updated;
  }

  /// Batalkan order lewat backend (stok bahan dikembalikan server).
  /// Backend menolak batal untuk order yang sudah dibayar.
  Future<Order> cancelOrder(Order order) async {
    final updated = await OrderService.instance.cancelOrder(
      int.parse(order.id),
    );
    _replaceOrder(updated);
    unawaited(reloadStocks());
    return updated;
  }
}

/// Jalankan Future tanpa menunggu (fire-and-forget) dengan penanganan error.
void unawaited(Future<void> future) {
  future.catchError((_) {
    // Kegagalan refresh stok diabaikan — data akan segar saat halaman
    // stok dibuka berikutnya.
  });
}
