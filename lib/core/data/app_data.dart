import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'models.dart';
import '../network/api_exception.dart';
import '../services/auth_service.dart';
import '../services/account_store.dart';
import '../services/charge_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/receipt_settings_service.dart';
import '../services/sales_history_service.dart';
import '../services/shift_service.dart';
import '../services/stock_service.dart';
import 'local_cache.dart';

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
    _productsFetchedAt = null;
    _charges = [];
    _chargesError = null;
    _chargesFetchedAt = null;
    _orders = [];
    _ordersDate = _today();
    _orderListDate = _today();
    _customers = [];
    _salesHistory = null;
    _salesFilter = null;
    _productSales = [];
    _currentShift = null;
    _receiptFooter = kDefaultReceiptFooter;
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

    final userId = _currentUser?.id;

    try {
      final fetched = await StockService.instance.fetchProductStock(
        outlet.id,
        withDetail: withDetail,
      );
      // Ganti akun bisa terjadi di tengah fetch: jangan isi state akun baru
      // dengan stok outlet akun lama.
      if (_currentUser?.id != userId) return;
      _productStocks = fetched;
    } on ApiException catch (e) {
      if (_currentUser?.id != userId) return;
      _stockError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
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

    final userId = _currentUser?.id;

    try {
      final fetched = await StockService.instance.fetchComponentStock(
        outlet.id,
      );
      if (_currentUser?.id != userId) return;
      _componentStocks = fetched;
    } on ApiException catch (e) {
      if (_currentUser?.id != userId) return;
      _componentError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
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

  /// Logout perangkat ini: hapus token di backend, keluarkan akun aktif
/// dari daftar, lalu otomatis pindah ke akun lain bila ada.
  ///
  /// Gagal request ke backend (server mati / token sudah hangus / 401)
  /// TIDAK boleh menggagalkan logout — pembersihan lokal tetap jalan.
  Future<void> logout() async {
    SavedAccount? next;
    try {
      next = await AuthService.instance.logout();
    } catch (_) {
      // Abaikan error API; AuthService.logout sudah membersihkan token.
    }

    if (next != null) {
      switchAccount(next.user, next.token);
    } else {
      await clearSessionLocal();
    }
  }

  /// Logout dari semua perangkat: cabut seluruh token user di backend,
  /// hapus semua akun tersimpan, dan buang cache outlet.
  Future<void> logoutAll() async {
    final outletId = _currentUser?.outlet?.id;
    try {
      await AuthService.instance.logoutAll();
    } catch (_) {
      // Tetap bersihkan lokal walau backend tidak terjangkau.
    }

    if (outletId != null) {
      unawaited(LocalCache.instance.remove('charges_outlet_$outletId'));
      unawaited(LocalCache.instance.remove('products_outlet_$outletId'));
    }
    await clearSessionLocal();
  }

  /// Ganti akun: terapkan token akun tujuan lalu reset state sesi.
  ///
  /// Cache persisten produk/charge sengaja TIDAK dihapus — cache di-key
  /// per outlet sehingga aman dipakai bersama antar akun.
  void switchAccount(AuthUser user, String token) {
    AuthService.instance.applyToken(token);
    setSession(user);
  }

  /// Bersihkan sesi & seluruh data TANPA memanggil API logout backend.
  ///
  /// Dipakai saat sesi hangus di tengah pemakaian (401) atau saat tidak
  /// ada akun lain setelah logout.
  Future<void> clearSessionLocal() async {
    await AuthService.instance.clearLocalSession();
    _currentUser = null;
    _productStocks = [];
    _stockError = null;
    _componentStocks = [];
    _componentError = null;
    _products = [];
    _productsError = null;
    _productsFetchedAt = null;
    _charges = [];
    _chargesError = null;
    _chargesFetchedAt = null;
    _orders = [];
    _ordersDate = _today();
    _orderListDate = _today();
    _customers = [];
    _salesHistory = null;
    _salesFilter = null;
    _productSales = [];
    _currentShift = null;
    _receiptFooter = kDefaultReceiptFooter;
    _cart.clear();
    notifyListeners();
  }

  // ---- Data dari API: produk untuk menu kasir (POS) ----
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  String? _productsError;

  /// Waktu daftar produk terakhir sukses diambil dari API — dasar
  /// keputusan segar/basi cache.
  DateTime? _productsFetchedAt;

  /// Batas usia daftar produk sebelum dianggap perlu segarkan di
  /// belakang layar. Menu lebih rawan berubah daripada charge
  /// (harga/tampil di menu), jadi batasnya lebih pendek.
  static const _productsTtl = Duration(minutes: 5);

  /// Daftar produk untuk menu kasir (dari API, TANPA info stok —
  /// semua produk tampil apa adanya).
  List<Product> get products => List.unmodifiable(_products);

  bool get isLoadingProducts => _isLoadingProducts;

  /// Pesan error terakhir saat memuat produk (`null` = tidak ada error).
  String? get productsError => _productsError;

  /// Muat daftar produk dengan pola cache-first:
  /// - Sesi berjalan: menu tampil langsung; bila usia data lewat TTL,
  ///   segarkan senyap di belakang layar (tanpa spinner, tanpa error).
  /// - App baru dibuka: cache persisten outlet tampil instan supaya
  ///   menu kasir tidak menunggu jaringan.
  /// - [force] (pull-to-refresh / tombol coba lagi) selalu fetch ke API.
  Future<void> loadProducts({bool force = false}) async {
    if (!force && _products.isNotEmpty) {
      if (_productsFresh) return;
      unawaited(_refreshProductsSilently());
      return;
    }

    if (!force) {
      final outlet = currentOutlet;
      if (outlet != null) {
        final entry = await LocalCache.instance.readJson(
          'products_outlet_${outlet.id}',
        );
        final cached = _decodeProducts(entry?.payload);
        if (cached != null && cached.isNotEmpty) {
          _products = cached;
          _productsFetchedAt = entry!.savedAt;
          notifyListeners();
          if (_productsFresh) return;
          unawaited(_refreshProductsSilently());
          return;
        }
      }
    }

    await _fetchProducts();
  }

  bool get _productsFresh =>
      _productsFetchedAt != null &&
      DateTime.now().difference(_productsFetchedAt!) < _productsTtl;

  /// Ubah payload cache jadi daftar [Product]; `null` bila formatnya
  /// tidak dikenali (cache rusak/versi lama) — dianggap tidak ada cache
  /// sehingga alur fetch normal tetap berjalan.
  List<Product>? _decodeProducts(Object? payload) {
    if (payload is! List) return null;
    try {
      return payload
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Fetch produk ke API dengan spinner/error seperti semula, lalu
  /// simpan hasilnya ke cache persisten outlet.
  Future<void> _fetchProducts() async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _productsError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }
    final userId = _currentUser?.id;

    _isLoadingProducts = true;
    _productsError = null;
    notifyListeners();

    try {
      final fresh = await ProductService.instance.fetchProducts(outlet.id);
      // Logout/ganti akun bisa terjadi di tengah fetch: jangan isi
      // state/cache milik sesi yang barusan ditinggalkan.
      if (_currentUser?.id != userId) return;
      _products = fresh;
      _productsFetchedAt = DateTime.now();
      _persistProducts(fresh);
    } on ApiException catch (e) {
      // Jangan tampilkan error sesi lama di layar akun baru.
      if (_currentUser?.id != userId) return;
      _productsError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
      _productsError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Segarkan produk di belakang layar: tanpa spinner, tanpa pesan
  /// error — menu yang sedang tampil tetap dipakai bila jaringan
  /// gagal; dicoba lagi pada pembukaan halaman berikutnya.
  Future<void> _refreshProductsSilently() async {
    final outlet = currentOutlet;
    if (outlet == null) return;
    final userId = _currentUser?.id;
    // Catat waktu percobaan sekarang juga supaya pembukaan halaman
    // beruntun tidak memicu beberapa fetch sekaligus.
    _productsFetchedAt = DateTime.now();
    try {
      final fresh = await ProductService.instance.fetchProducts(outlet.id);
      if (_currentUser?.id != userId) return;
      _products = fresh;
      _persistProducts(fresh);
      notifyListeners();
    } catch (_) {
      // Diamkan: menu lama tetap tampil.
    }
  }

  /// Simpan daftar produk ke cache persisten outlet saat ini.
  void _persistProducts(List<Product> fresh) {
    final outlet = currentOutlet;
    if (outlet == null) return;
    unawaited(
      LocalCache.instance.writeJson(
        'products_outlet_${outlet.id}',
        fresh.map((p) => p.toJson()).toList(),
      ),
    );
  }

  // ---- Data dari API: master charge (toggle checkout) ----
  List<MasterCharge> _charges = [];
  bool _isLoadingCharges = false;
  String? _chargesError;

  /// Waktu daftar charge terakhir sukses diambil dari API — dasar
  /// keputusan segar/basi cache.
  DateTime? _chargesFetchedAt;

  /// Batas usia daftar charge sebelum dianggap perlu segarkan di
  /// belakang layar. Master charge jarang berubah, cukup 10 menit.
  static const _chargesTtl = Duration(minutes: 10);

  /// Daftar charge aktif (pajak, diskon, dll) dari backend.
  List<MasterCharge> get charges => List.unmodifiable(_charges);

  bool get isLoadingCharges => _isLoadingCharges;

  String? get chargesError => _chargesError;

  /// Muat daftar charge aktif dengan pola cache-first:
  /// - Sesi berjalan: toggle tampil langsung; bila usia data lewat TTL,
  ///   segarkan senyap di belakang layar (tanpa spinner, tanpa error).
  /// - App baru dibuka: cache persisten outlet tampil instan supaya
  ///   toggle checkout tidak menunggu jaringan.
  /// - [force] selalu fetch langsung ke API.
  Future<void> loadCharges({bool force = false}) async {
    if (!force && _charges.isNotEmpty) {
      if (_chargesFresh) return;
      unawaited(_refreshChargesSilently());
      return;
    }

    if (!force) {
      final outlet = currentOutlet;
      if (outlet != null) {
        final entry = await LocalCache.instance.readJson(
          'charges_outlet_${outlet.id}',
        );
        final cached = _decodeCharges(entry?.payload);
        if (cached != null && cached.isNotEmpty) {
          _charges = cached;
          _chargesFetchedAt = entry!.savedAt;
          notifyListeners();
          if (_chargesFresh) return;
          unawaited(_refreshChargesSilently());
          return;
        }
      }
    }

    await _fetchCharges();
  }

  bool get _chargesFresh =>
      _chargesFetchedAt != null &&
      DateTime.now().difference(_chargesFetchedAt!) < _chargesTtl;

  /// Ubah payload cache jadi daftar [MasterCharge]; `null` bila formatnya
  /// tidak dikenali (cache rusak/versi lama) — dianggap tidak ada cache
  /// sehingga alur fetch normal tetap berjalan.
  List<MasterCharge>? _decodeCharges(Object? payload) {
    if (payload is! List) return null;
    try {
      return payload
          .map((e) => MasterCharge.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Fetch charge ke API dengan spinner/error seperti semula, lalu
  /// simpan hasilnya ke cache persisten outlet.
  Future<void> _fetchCharges() async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _chargesError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }
    final userId = _currentUser?.id;

    _isLoadingCharges = true;
    _chargesError = null;
    notifyListeners();

    try {
      final fresh = await ChargeService.instance.fetchCharges();
      // Logout/ganti akun bisa terjadi di tengah fetch: jangan isi
      // state/cache milik sesi yang barusan ditinggalkan.
      if (_currentUser?.id != userId) return;
      _charges = fresh;
      _chargesFetchedAt = DateTime.now();
      _persistCharges(fresh);
    } on ApiException catch (e) {
      // Jangan tampilkan error sesi lama di layar akun baru.
      if (_currentUser?.id != userId) return;
      _chargesError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
      _chargesError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingCharges = false;
      notifyListeners();
    }
  }

  /// Segarkan charge di belakang layar: tanpa spinner, tanpa pesan
  /// error — toggle yang sedang tampil tetap dipakai bila jaringan
  /// gagal; dicoba lagi pada pembukaan checkout berikutnya.
  Future<void> _refreshChargesSilently() async {
    final outlet = currentOutlet;
    if (outlet == null) return;
    final userId = _currentUser?.id;
    // Catat waktu percobaan sekarang juga supaya pembukaan halaman
    // beruntun tidak memicu beberapa fetch sekaligus.
    _chargesFetchedAt = DateTime.now();
    try {
      final fresh = await ChargeService.instance.fetchCharges();
      if (_currentUser?.id != userId) return;
      _charges = fresh;
      _persistCharges(fresh);
      notifyListeners();
    } catch (_) {
      // Diamkan: daftar lama tetap tampil.
    }
  }

  /// Simpan daftar charge ke cache persisten outlet saat ini.
  void _persistCharges(List<MasterCharge> fresh) {
    final outlet = currentOutlet;
    if (outlet == null) return;
    unawaited(
      LocalCache.instance.writeJson(
        'charges_outlet_${outlet.id}',
        fresh.map((c) => c.toJson()).toList(),
      ),
    );
  }

  // ---- Data dari API: orders (transaksi kasir) ----
  List<Order> _orders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;

  /// Tanggal data yang **sedang dimuat** di [orders].
  ///
  /// Dipakai untuk tahu kapan cache harus dibuang saat tanggal berganti.
  DateTime _ordersDate = _today();

  /// Tanggal yang dipilih kasir di menu Daftar Pesanan.
  ///
  /// Terpisah dari [_ordersDate] supaya Dashboard (yang selalu butuh data
  /// hari ini) tidak menghapus pilihan tanggal kasir.
  DateTime _orderListDate = _today();

  /// Daftar order pada [ordersDate] untuk outlet saat ini (dari API).
  List<Order> get orders => List.unmodifiable(_orders);

  /// Tanggal data order yang sedang dimuat.
  DateTime get ordersDate => _ordersDate;

  /// Tanggal yang sedang dipilih di Daftar Pesanan (bertahan antar menu).
  DateTime get orderListDate => _orderListDate;

  bool get isLoadingOrders => _isLoadingOrders;

  String? get ordersError => _ordersError;

  /// Muat daftar order untuk [date] (default: hari ini).
  ///
  /// Dashboard dan tutup shift memanggil ini dengan tanggal hari ini,
  /// sedangkan Daftar Pesanan memakai [loadOrdersForDate] agar pilihan
  /// tanggal kasir tersimpan.
  Future<void> loadOrders({DateTime? date}) async {
    final outlet = currentOutlet;
    if (outlet == null) {
      _ordersError = 'Outlet tidak ditemukan untuk user ini.';
      notifyListeners();
      return;
    }

    final target = _dateOnly(date ?? _today());
    // Ganti tanggal: buang kartu lama supaya order kemarin tidak sempat
    // tampil di bawah label tanggal yang baru.
    if (!_isSameDay(target, _ordersDate)) {
      _ordersDate = target;
      _orders = [];
    }

    _isLoadingOrders = true;
    _ordersError = null;
    notifyListeners();

    final userId = _currentUser?.id;

    try {
      final fetched = await OrderService.instance.fetchOrders(
        outlet.id,
        date: target,
      );
      if (_currentUser?.id != userId) return;
      _orders = fetched;
    } on ApiException catch (e) {
      if (_currentUser?.id != userId) return;
      _ordersError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
      _ordersError = 'Tidak dapat terhubung ke server.';
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  /// Muat order untuk tanggal tertentu dari Daftar Pesanan.
  ///
  /// Tanggal pilihan kasir disimpan di [orderListDate] supaya tetap
  /// terpakai saat halaman dibuka ulang (mis. setelah pindah menu).
  Future<void> loadOrdersForDate(DateTime date) async {
    _orderListDate = _dateOnly(date);
    await loadOrders(date: _orderListDate);
  }

  /// Ganti order lama dengan versi terbaru dari backend (berdasarkan id).
  void _replaceOrder(Order updated) {
    final index = _orders.indexWhere((o) => o.id == updated.id);
    if (index >= 0) {
      _orders[index] = updated;
    } else if (_isSameDay(_dateOnly(updated.createdAt), _ordersDate)) {
      // Order baru hanya masuk kalau tanggalnya cocok dengan daftar yang
      // sedang tampil, supaya filter tanggal tidak bocor.
      _orders.insert(0, updated);
    }
    notifyListeners();
  }

  /// Tanggal hari ini tanpa jam — dasar filter Daftar Pesanan.
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

    final userId = _currentUser?.id;

    try {
      final fetched = await OrderService.instance.fetchCustomers(outlet.id);
      if (_currentUser?.id != userId) return;
      _customers = fetched;
    } on ApiException catch (e) {
      if (_currentUser?.id != userId) return;
      _customersError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
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

    final userId = _currentUser?.id;

    try {
      final history = await SalesHistoryService.instance.fetch(filter);
      if (_currentUser?.id != userId) return;
      _salesHistory = history;
      _salesFilter = filter;
    } on ApiException catch (e) {
      if (_currentUser?.id != userId) return;
      _salesError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
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

    final userId = _currentUser?.id;

    try {
      final fetched = await SalesHistoryService.instance.fetchProducts(filter);
      if (_currentUser?.id != userId) return;
      _productSales = fetched;
    } on ApiException catch (e) {
      if (_currentUser?.id != userId) return;
      _productSalesError = e.message;
    } catch (_) {
      if (_currentUser?.id != userId) return;
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

    final userId = _currentUser?.id;

    try {
      final shift = await ShiftService.instance.fetchCurrent();
      if (_currentUser?.id != userId) return;
      _currentShift = shift;
    } catch (_) {
      // Gagal memuat (server mati dll): dianggap belum ada shift agar
      // kasir tetap diarahkan ke "Buka Shift"; bisa dicoba lagi.
      if (_currentUser?.id != userId) return;
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

  // ---- Pengaturan struk ----

  String _receiptFooter = kDefaultReceiptFooter;

  /// Teks penutup struk outlet saat ini. Bawaannya
  /// "Terima kasih telah berbelanja" sampai user mengubahnya di menu
  /// Pengaturan Struk.
  String get receiptFooter => _receiptFooter;

  /// Muat teks penutup struk outlet saat ini (dipanggil saat masuk
  /// shell, termasuk setelah ganti akun).
  ///
  /// Mengembalikan `true` bila data berasal dari server. `false` berarti
  /// API tidak terjangkau dan teks cache (atau default) yang dipakai —
  /// halaman pengaturan memakai ini untuk memberi tahu user.
  Future<bool> loadReceiptFooter() async {
    final outletId = currentOutlet?.id;
    final userId = _currentUser?.id;

    var fromServer = false;
    try {
      // Teks dari versi lama (masih lokal) diunggah sekali bila backend
      // masih kosong, supaya tidak hilang.
      await ReceiptSettingsService.instance.uploadLocalFooterIfMissing(
        outletId,
      );

      final footer = await ReceiptSettingsService.instance.fetchFooter(
        outletId,
      );
      fromServer = true;
      // Ganti akun bisa terjadi saat baca: jangan pasang teks outlet lama
      // ke sesi baru.
      if (_currentUser?.id != userId) return fromServer;
      _receiptFooter = footer;
      notifyListeners();
    } catch (_) {
      // Gagal baca: pakai teks yang sedang tampil.
    }
    return fromServer;
  }

  /// Simpan teks penutup struk ke backend. Teks kosong kembali ke default.
  ///
  /// Melempar `ApiException` bila server menolak, supaya halaman
  /// pengaturan bisa menampilkan pesan aslinya.
  Future<void> saveReceiptFooter(String text) async {
    final outletId = currentOutlet?.id;
    final userId = _currentUser?.id;

    await ReceiptSettingsService.instance.saveFooter(outletId, text);

    if (_currentUser?.id != userId) return;
    _receiptFooter = ReceiptSettingsService.normalizeFooter(text);
    notifyListeners();
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

  /// Order yang lunas (dan tidak dibatalkan) pada hari ini.
  ///
  /// Dibatasi hari ini karena [_orders] bisa berisi tanggal lain saat
  /// kasir membuka tanggal lampau di Daftar Pesanan, sedangkan angka
  /// Dashboard selalu soal hari ini.
  List<Order> get paidOrders => _orders
      .where(
        (o) =>
            o.isPaid &&
            o.status != OrderStatus.dibatalkan &&
            _isSameDay(o.createdAt, DateTime.now()),
      )
      .toList();

  /// Omzet dari order lunas yang dibuat hari ini.
  int get todayRevenue =>
      paidOrders.fold(0, (sum, o) => sum + o.total);

  /// Bahan dengan stok <= ambang minimum (untuk kartu Stok Kritis).
  List<ComponentStock> get criticalStock =>
      _componentStocks.where((s) => s.isCritical).toList();

  /// Aktivitas terakhir untuk dashboard (maks 4, terbaru dulu).
  ///
  /// Saat shift aktif, hanya order yang dibuat sejak shift dibuka —
  /// sesuai periode kerja kasir. Tanpa shift: fallback ke order hari ini.
  /// Daftar [_orders] sendiri selalu satu tanggal, jadi shift yang lewat
  /// tengah malam hanya menampilkan bagian hari ini di kartu aktivitas.
  List<Order> get recentOrders {
    final shift = currentShift;
    // Daftar bisa sedang menampilkan tanggal lampau; dashboard hanya
    // menampilkan aktivitas shift aktif (atau hari ini bila belum ada
    // shift), bukan tanggal yang sedang dibuka di Daftar Pesanan.
    final source = shift != null
        ? _orders
              .where((o) => !o.createdAt.isBefore(shift.startTime))
              .toList()
        : _orders
              .where((o) => _isSameDay(o.createdAt, DateTime.now()))
              .toList();
    final sorted =
        [...source]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(4).toList();
  }

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
    // Hanya disisipkan bila daftar yang sedang tampil memang hari ini —
    // kasir bisa sedang membuka tanggal lain di Daftar Pesanan.
    if (_isSameDay(_dateOnly(result.order.createdAt), _ordersDate)) {
      _orders.insert(0, result.order);
    }
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

  /// Hapus satu item dari order (backend mengembalikan stok bahan item
  /// dan menghitung ulang total). Order lama di daftar diganti versi baru
  /// sehingga tampilan total kartu ikut berubah.
  Future<Order> removeOrderItem(Order order, OrderItem item) async {
    final updated = await OrderService.instance.removeOrderItem(
      int.parse(order.id),
      int.parse(item.itemId),
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
