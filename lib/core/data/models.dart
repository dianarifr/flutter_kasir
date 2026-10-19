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

class StockItem {
  final String id;
  final String name;
  final String unit;
  final int minStock;
  int stock;

  StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
  });

  bool get isCritical => stock <= minStock;
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
}

class Order {
  final String id;
  String customer;
  final DateTime createdAt;
  final int queueNumber;
  final List<OrderItem> items;
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
    this.customer = '',
    required this.createdAt,
    required this.queueNumber,
    required this.items,
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
}
