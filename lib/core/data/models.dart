import '../utils/formatters.dart';

/// Status pesanan.
enum OrderStatus { diproses, selesai, dibatalkan }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.diproses:
        return 'Pesanan Diproses';
      case OrderStatus.selesai:
        return 'Pesanan Selesai';
      case OrderStatus.dibatalkan:
        return 'Pesanan Dibatalkan';
    }
  }
}

/// Metode pembayaran.
enum PaymentMethod { tunai, nonTunai, campuran }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.tunai:
        return 'Tunai';
      case PaymentMethod.nonTunai:
        return 'Non Tunai';
      case PaymentMethod.campuran:
        return 'Pembayaran Campuran';
    }
  }

  /// Nilai enum yang dikirim ke backend.
  String get apiLabel {
    switch (this) {
      case PaymentMethod.tunai:
        return 'tunai';
      case PaymentMethod.nonTunai:
        return 'non_tunai';
      case PaymentMethod.campuran:
        return 'campuran';
    }
  }
}

class Product {
  final String id;
  final String name;
  final int price;

  /// URL absolut gambar produk dari API (bisa null bila belum diupload).
  final String? imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    // Backend mengirim id integer; di app dipakai sebagai String
    // supaya kompatibel dengan keranjang/order yang sudah ada.
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toInt() ?? 0,
    imageUrl: json['image_url'] as String?,
  );

  /// Bentuk minimal untuk cache persisten (LocalCache) — simetris dengan
  /// [fromJson] sehingga round-trip tidak mengubah data.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    if (imageUrl != null) 'image_url': imageUrl,
  };
}

/// Outlet tempat user (kasir) bertugas.
class Outlet {
  final int id;
  final String name;
  final String address;

  const Outlet({required this.id, required this.name, this.address = ''});

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
  );
}

/// User yang sedang login, termasuk outlet-nya (bisa null untuk admin).
class AuthUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final Outlet? outlet;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.outlet,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'kasir',
    outlet: json['outlet'] == null
        ? null
        : Outlet.fromJson(json['outlet'] as Map<String, dynamic>),
  );
}

/// Satu komponen penyusun produk beserta stoknya di outlet.
class ProductStockComponent {
  final int componentId;
  final String componentName;
  final int qtyPerPortion;
  final int currentStock;
  final int maxPortions;

  const ProductStockComponent({
    required this.componentId,
    required this.componentName,
    required this.qtyPerPortion,
    required this.currentStock,
    required this.maxPortions,
  });

  factory ProductStockComponent.fromJson(Map<String, dynamic> json) =>
      ProductStockComponent(
        componentId: json['component_id'] as int,
        componentName: json['component_name'] as String? ?? '',
        qtyPerPortion: json['qty_per_portion'] as int? ?? 0,
        currentStock: json['current_stock'] as int? ?? 0,
        maxPortions: json['max_portions'] as int? ?? 0,
      );
}

/// Stok sebuah produk pada satu outlet (dihitung backend dari resep/BOM).
///
/// [stock] bernilai `null` jika produk tidak punya resep
/// ([isStockTracked] == false) sehingga stoknya tidak dilacak.
class ProductStock {
  final int id;
  final String name;
  final double price;
  final int? stock;
  final bool isStockTracked;
  final String? bottleneckComponent;
  final List<ProductStockComponent> components;

  const ProductStock({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.isStockTracked,
    this.bottleneckComponent,
    this.components = const [],
  });

  factory ProductStock.fromJson(Map<String, dynamic> json) => ProductStock(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    stock: json['stock'] as int?,
    isStockTracked: json['is_stock_tracked'] as bool? ?? false,
    bottleneckComponent: json['bottleneck_component'] as String?,
    components: (json['components'] as List<dynamic>? ?? const [])
        .map((e) => ProductStockComponent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Stok <= ambang batas dianggap kritis (untuk label warna di UI).
  bool get isCritical => isStockTracked && (stock ?? 0) <= criticalThreshold;

  /// Stok habis total.
  bool get isOutOfStock => isStockTracked && (stock ?? 0) <= 0;

  /// Label status stok untuk ditampilkan di UI.
  String get statusLabel {
    if (!isStockTracked) return 'Tidak Dilacak';
    if (isOutOfStock) return 'Habis';
    if (isCritical) return 'Kritis';
    return 'Aman';
  }

  /// Ambang batas stok kritis (porsi).
  static const int criticalThreshold = 10;
}

/// Sisa stok satu bahan/komponen di outlet.
class ComponentStock {
  final int id;
  final String name;
  final String unit;
  final int currentStock;

  /// Ambang minimum yang diatur admin; `0` berarti tidak ada ambang.
  final int minStock;

  const ComponentStock({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minStock,
  });

  factory ComponentStock.fromJson(Map<String, dynamic> json) => ComponentStock(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    currentStock: json['current_stock'] as int? ?? 0,
    minStock: json['min_stock'] as int? ?? 0,
  );

  /// Stok <= ambang minimum yang diatur admin dianggap kritis.
  bool get isCritical => currentStock <= minStock;

  /// Label status stok untuk ditampilkan di UI.
  String get statusLabel => isCritical ? 'Kritis' : 'Aman';
}

class OrderItem {
  final String productId;
  final String name;
  final int price;
  final int qty;
  final String note;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.note = '',
  });

  int get subtotal => price * qty;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    // Backend mengirim product_id integer; di app dipakai sebagai String.
    productId: (json['product_id'] as num?)?.toString() ?? '-',
    name: json['product_name'] as String? ?? '',
    price: _asInt(json['price']),
    qty: _asInt(json['qty']),
    note: json['note'] as String? ?? '',
  );
}

/// Satu charge (pajak/diskon/biaya) yang dikenakan pada sebuah order.
///
/// [amount] bertanda: negatif = diskon (mengurangi total), positif = biaya.
class OrderChargeLine {
  final String name;
  final double value;
  final bool isPercentage;
  final double amount;

  const OrderChargeLine({
    required this.name,
    required this.value,
    required this.isPercentage,
    required this.amount,
  });

  factory OrderChargeLine.fromJson(Map<String, dynamic> json) =>
      OrderChargeLine(
        name: json['name'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        isPercentage: json['is_percentage'] as bool? ?? false,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}

/// Peringatan bahan dari backend saat order disimpan: bahan yang
/// jadi habis/minus setelah stok dipotong. Transaksi TIDAK dibatalkan.
class StockWarning {
  final int componentId;
  final String componentName;
  final List<String> products;
  final int stockBefore;
  final int stockAfter;

  const StockWarning({
    required this.componentId,
    required this.componentName,
    required this.products,
    required this.stockBefore,
    required this.stockAfter,
  });

  /// Teks siap tampil di popup, contoh:
  /// "Chili oil habis (terpakai oleh: Dimsum besar mentai 8)".
  String get label {
    final state = stockAfter < 0 ? 'kurang' : 'habis';
    final usedBy = products.isEmpty ? '' : ' (terpakai oleh: ${products.join(', ')})';
    return '$componentName $state$usedBy';
  }

  factory StockWarning.fromJson(Map<String, dynamic> json) => StockWarning(
    componentId: _asInt(json['component_id']),
    componentName: json['component_name'] as String? ?? '-',
    products: (json['products'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    stockBefore: _asInt(json['stock_before']),
    stockAfter: _asInt(json['stock_after']),
  );
}

/// Master charge aktif dari backend (dasar toggle dinamis di checkout).
class MasterCharge {
  final int id;
  final String name;

  /// Nilai charge: persen bila [isPercentage], else nominal rupiah.
  final double value;
  final bool isPercentage;

  /// 'biaya' menambah total, 'diskon' mengurangi total.
  final String type;

  const MasterCharge({
    required this.id,
    required this.name,
    required this.value,
    required this.isPercentage,
    required this.type,
  });

  bool get isDiscount => type == 'diskon';

  /// Label untuk UI, contoh: "10%" atau "Rp 2.000".
  String get valueLabel =>
      isPercentage ? '${trimValue(value)}%' : 'Rp ${trimValue(value)}';

  /// Angka rapi tanpa desain ".0", contoh: 10 -> "10", 12.5 -> "12.5".
  static String trimValue(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  factory MasterCharge.fromJson(Map<String, dynamic> json) => MasterCharge(
    id: _asInt(json['id']),
    name: json['name'] as String? ?? '',
    value: (json['value'] as num?)?.toDouble() ?? 0,
    isPercentage: json['is_percentage'] as bool? ?? false,
    type: json['type'] as String? ?? 'biaya',
  );

  /// Bentuk minimal untuk cache persisten (LocalCache) — simetris dengan
  /// [fromJson] sehingga round-trip tidak mengubah data.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'is_percentage': isPercentage,
    'type': type,
  };
}

/// Konversi angka dari JSON yang aman (bisa int, double, atau null).
int _asInt(dynamic value) => (value as num?)?.round() ?? 0;

class Order {
  final String id;

  /// Kode struk dari backend, contoh: INV201026-0001.
  final String code;
  String customer;
  final DateTime createdAt;
  final int queueNumber;
  final List<OrderItem> items;
  final List<OrderChargeLine> charges;
  final int subtotal;
  final int discount;
  final int extraFee;
  bool isPaid;
  OrderStatus status;
  PaymentMethod? paymentMethod;
  int cashGiven;
  int changeGiven;
  int splitCash;
  int splitNonCash;

  Order({
    required this.id,
    this.code = '',
    this.customer = '',
    required this.createdAt,
    required this.queueNumber,
    required this.items,
    this.charges = const [],
    required this.subtotal,
    this.discount = 0,
    this.extraFee = 0,
    this.isPaid = false,
    this.status = OrderStatus.diproses,
    this.paymentMethod,
    this.cashGiven = 0,
    this.changeGiven = 0,
    this.splitCash = 0,
    this.splitNonCash = 0,
  });

  int get total => subtotal - discount + extraFee;

  String get customerLabel => customer.isEmpty ? 'Umum' : customer;

  String get dateLabel => '${formatDate(createdAt)} - Antrian $queueNumber';

  String get itemsSummary =>
      items.map((e) => '${e.qty}x ${e.name}').join(' • ');

  /// Label untuk tampilan: pakai [code] bila ada, fallback ke id.
  String get displayId => code.isNotEmpty ? code : id;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: (json['id'] as num?)?.toString() ?? '-',
    code: json['code'] as String? ?? '',
    customer: json['customer_name'] as String? ?? '',
    createdAt:
        // toISOString() backend mengirim UTC (akhiran Z); konversi ke
        // waktu lokal perangkat supaya jam yang tampil WIB.
        DateTime.tryParse(json['created_at'] as String? ?? '')
            ?.toLocal() ??
        DateTime.now(),
    queueNumber: _asInt(json['queue_number']),
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    charges: (json['charges'] as List<dynamic>? ?? const [])
        .map((e) => OrderChargeLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    subtotal: _asInt(json['subtotal']),
    discount: _asInt(json['discount']),
    extraFee: _asInt(json['extra_fee']),
    isPaid: json['is_paid'] as bool? ?? false,
    status: _statusFromApi(json['status'] as String?),
    paymentMethod: _paymentFromApi(json['payment_method'] as String?),
    cashGiven: _asInt(json['cash_given']),
    changeGiven: _asInt(json['change_amount']),
    splitCash: _asInt(json['split_cash']),
    splitNonCash: _asInt(json['split_non_cash']),
  );

  static OrderStatus _statusFromApi(String? raw) {
    switch (raw) {
      case 'selesai':
        return OrderStatus.selesai;
      case 'dibatalkan':
        return OrderStatus.dibatalkan;
      default:
        return OrderStatus.diproses;
    }
  }

  static PaymentMethod? _paymentFromApi(String? raw) {
    switch (raw) {
      case 'tunai':
        return PaymentMethod.tunai;
      case 'non_tunai':
        return PaymentMethod.nonTunai;
      case 'campuran':
        return PaymentMethod.campuran;
      default:
        return null;
    }
  }

  /// Bentuk enum untuk dikirim ke backend.
  String? get paymentMethodApi {
    switch (paymentMethod) {
      case PaymentMethod.tunai:
        return 'tunai';
      case PaymentMethod.nonTunai:
        return 'non_tunai';
      case PaymentMethod.campuran:
        return 'campuran';
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Riwayat penjualan (/sales-history)
// ---------------------------------------------------------------------------

/// Filter periode untuk Riwayat Penjualan — sekaligus bentuk query
/// params yang dikirim ke backend.
class SalesFilter {
  /// `daily` | `monthly` | `yearly` | `custom`.
  final String period;

  /// Harian: YYYY-MM-DD.
  final String? date;

  /// Bulanan: YYYY-MM.
  final String? month;

  /// Tahunan: YYYY.
  final String? year;

  /// Custom: batas bawah/atas (inklusif), YYYY-MM-DD.
  final String? startDate;
  final String? endDate;

  const SalesFilter({
    required this.period,
    this.date,
    this.month,
    this.year,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toQuery() => {
    'period': period,
    if (period == 'daily') 'date': date,
    if (period == 'monthly') 'month': month,
    if (period == 'yearly') 'year': year,
    if (period == 'custom') ...{
      'start_date': startDate,
      'end_date': endDate,
    },
  };

  /// Label periode untuk tampilan, contoh: "Sen, 20 Okt 2026" / "Okt 2026".
  String get displayLabel {
    switch (period) {
      case 'daily':
        return formatDateShort(DateTime.parse(date!));
      case 'monthly':
        return formatMonthYear(DateTime.parse('$month-01'));
      case 'yearly':
        return year!;
      default:
        return formatDateRange(
          DateTime.parse(startDate!),
          DateTime.parse(endDate!),
        );
    }
  }
}

/// Ringkasan penjualan (kartu statistik di halaman Riwayat Penjualan).
class SalesSummary {
  final int transactionCount;
  final int productsSold;

  /// Total uang masuk (Σ total_price order lunas).
  final int omzet;

  const SalesSummary({
    required this.transactionCount,
    required this.productsSold,
    required this.omzet,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
    transactionCount: _asInt(json['transaction_count']),
    productsSold: _asInt(json['products_sold']),
    omzet: _asInt(json['omzet']),
  );
}

/// Satu transaksi lunas di daftar Riwayat Penjualan (format ringan —
/// tanpa item/charge supaya payload tetap kecil).
class SalesOrder {
  final String id;
  final String code;
  final String customer;

  /// `tunai` | `non_tunai` | `campuran` (raw dari backend).
  final String? paymentMethod;
  final int total;
  final String cashierName;
  final DateTime createdAt;

  const SalesOrder({
    required this.id,
    required this.code,
    required this.customer,
    this.paymentMethod,
    required this.total,
    required this.cashierName,
    required this.createdAt,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) => SalesOrder(
    id: (json['id'] ?? '').toString(),
    code: json['code'] as String? ?? '',
    customer: json['customer_name'] as String? ?? '',
    paymentMethod: json['payment_method'] as String?,
    total: _asInt(json['total_price']),
    cashierName: json['cashier_name'] as String? ?? '',
    createdAt:
        // Konversi UTC -> lokal, sama seperti di Order.fromJson.
        DateTime.tryParse(json['created_at'] as String? ?? '')
            ?.toLocal() ??
        DateTime.now(),
  );

  /// Label metode pembayaran untuk tampilan.
  String get paymentLabel {
    switch (paymentMethod) {
      case 'tunai':
        return 'Tunai';
      case 'non_tunai':
        return 'Non Tunai';
      case 'campuran':
        return 'Campuran';
      default:
        return '-';
    }
  }
}

/// Hasil GET /sales-history: rentang + ringkasan + daftar transaksi.
class SalesHistory {
  final String period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final SalesSummary summary;
  final List<SalesOrder> orders;

  const SalesHistory({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.summary,
    required this.orders,
  });

  factory SalesHistory.fromJson(Map<String, dynamic> json) {
    final range = json['range'] as Map<String, dynamic>? ?? {};
    final orders = json['orders'] as List<dynamic>? ?? [];

    return SalesHistory(
      period: json['period'] as String? ?? '',
      rangeStart:
          DateTime.tryParse(range['start'] as String? ?? '') ??
          DateTime.now(),
      rangeEnd: DateTime.tryParse(range['end'] as String? ?? '') ??
          DateTime.now(),
      summary: SalesSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      orders: orders
          .map((e) => SalesOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Agregasi penjualan satu produk dari /sales-history/products
/// (untuk halaman detail dari kartu "Produk Terjual").
class ProductSold {
  final String productId;
  final String productName;
  final int qty;

  /// Omzet kotor produk ini (Σ total_item_price, belum termasuk charge).
  final int revenue;

  const ProductSold({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.revenue,
  });

  factory ProductSold.fromJson(Map<String, dynamic> json) => ProductSold(
    productId: (json['product_id'] ?? '').toString(),
    productName: json['product_name'] as String? ?? '',
    qty: _asInt(json['qty']),
    revenue: _asInt(json['revenue']),
  );
}

/// Ringkasan live satu shift — dihitung server dari order lunas
/// milik shift tersebut (bukan dihitung ulang di client).
class ShiftSummary {
  final int transactionCount;

  /// Total penjualan shift (semua metode bayar, order lunas).
  final int salesTotal;

  /// Uang tunai yang masuk laci: penjualan tunai utuh + porsi tunai
  /// dari pembayaran campuran. Metode non tunai tidak masuk laci.
  final int cashTotal;

  /// Penjualan non tunai shift: metode non tunai penuh + porsi non
  /// tunai dari pembayaran campuran (= salesTotal - cashTotal).
  final int nonCashTotal;

  /// Perkiraan isi laci saat setor: modal awal + tunai terkumpul.
  final int expectedCash;

  const ShiftSummary({
    required this.transactionCount,
    required this.salesTotal,
    required this.cashTotal,
    required this.nonCashTotal,
    required this.expectedCash,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
    transactionCount: _asInt(json['transaction_count']),
    salesTotal: _asInt(json['sales_total']),
    cashTotal: _asInt(json['cash_total']),
    nonCashTotal: _asInt(json['non_cash_total']),
    expectedCash: _asInt(json['expected_cash']),
  );
}

/// Shift kasir: satu periode kerja dari "Buka Shift" (dengan modal
/// awal) sampai "Setor" / tutup shift. Shift terikat ke user login.
class Shift {
  final int id;
  final int userId;
  final int outletId;
  final DateTime startTime;

  /// `null` selama shift masih berjalan.
  final DateTime? endTime;

  /// Modal awal yang diinput kasir saat membuka shift.
  final int startingCash;

  /// Uang yang disetor saat menutup shift (`null` = belum ditutup).
  final int? endingCash;
  final String? notes;

  /// Ringkasan live; biasanya selalu ada dari backend.
  final ShiftSummary? summary;

  const Shift({
    required this.id,
    required this.userId,
    required this.outletId,
    required this.startTime,
    this.endTime,
    required this.startingCash,
    this.endingCash,
    this.notes,
    this.summary,
  });

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
    id: _asInt(json['id']),
    userId: _asInt(json['user_id']),
    outletId: _asInt(json['outlet_id']),
    startTime:
        // ISO8601 dari backend memakai UTC (toISOString()); konversi ke
        // waktu lokal perangkat supaya jam shift tampil WIB, bukan UTC.
        DateTime.tryParse(json['start_time'] as String? ?? '')
            ?.toLocal() ??
        DateTime.now(),
    endTime: json['end_time'] == null
        ? null
        : DateTime.tryParse(json['end_time'] as String)?.toLocal(),
    startingCash: _asInt(json['starting_cash']),
    endingCash: json['ending_cash'] == null
        ? null
        : _asInt(json['ending_cash']),
    notes: json['notes'] as String?,
    summary: json['summary'] == null
        ? null
        : ShiftSummary.fromJson(json['summary'] as Map<String, dynamic>),
  );

  /// Selisih laci saat tutup: disetor dikurangi perkiraan isi laci.
  /// Positif = lebih, negatif = kurang, 0 = pas.
  int? get selisih {
    final expected = summary?.expectedCash;
    final ending = endingCash;
    if (expected == null || ending == null) return null;
    return ending - expected;
  }
}
