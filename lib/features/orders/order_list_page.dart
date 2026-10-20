import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';
import '../pos/pos_payment_page.dart';
import '../receipt/receipt_page.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _query = '';
  final Map<String, bool> _expandedState = {};
  final Set<String> _checkedItems = {};

  AppData get _data => AppData.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Muat order dari API setiap halaman dibuka (initState jalan ulang
    // setiap tab dipilih).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _data.loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> _filteredOrders(OrderStatus? status) {
    final query = _query.trim().toLowerCase();
    final orders = _data.orders.where((order) {
      final matchStatus = status == null || order.status == status;
      final matchQuery =
          query.isEmpty ||
          order.displayId.toLowerCase().contains(query) ||
          order.customer.toLowerCase().contains(query);
      return matchStatus && matchQuery;
    }).toList();

    // Pesanan Diproses selalu paling atas, lalu Selesai, terakhir Dibatalkan.
    // Di dalam status yang sama, pesanan terbaru ditampilkan lebih dulu.
    int statusPriority(OrderStatus s) {
      switch (s) {
        case OrderStatus.diproses:
          return 0;
        case OrderStatus.selesai:
          return 1;
        case OrderStatus.dibatalkan:
          return 2;
      }
    }

    orders.sort((a, b) {
      final byStatus = statusPriority(a.status)
          .compareTo(statusPriority(b.status));
      if (byStatus != 0) return byStatus;
      return b.createdAt.compareTo(a.createdAt);
    });

    return orders;
  }

  void _toggleItem(Order order, OrderItem item) {
    final key = '${order.id}|${item.productId}';
    setState(() {
      if (!_checkedItems.add(key)) _checkedItems.remove(key);
    });
  }

  /// Batalkan pesanan lewat backend (stok bahan dikembalikan server).
  /// Backend menolak batal untuk order yang sudah dibayar.
  Future<void> _cancelOrder(Order order) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _data.cancelOrder(order);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pesanan dibatalkan, stok bahan dikembalikan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showMoreMenu(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Center(
                    child: Text(
                      'Struk Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceiptPage(order: order),
                      ),
                    );
                  },
                ),
                // "Tandai Selesai" dihapus: status selesai kini hanya
                // bisa dicapai lewat pembayaran supaya selalu ada
                // catatan pembayaran (nominal & metode).
                if (order.status == OrderStatus.diproses) ...[
                  const Divider(),
                  ListTile(
                    title: const Center(
                      child: Text(
                        'Batalkan Pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _cancelOrder(order);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _data,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pesanan'),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.inkMuted,
              indicatorColor: AppColors.accent,
              tabs: const [
                Tab(text: 'Semua'),
                Tab(text: 'Diproses'),
                Tab(text: 'Selesai'),
                Tab(text: 'Dibatalkan'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Bar pencarian
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (val) => setState(() => _query = val),
                  decoration: const InputDecoration(
                    hintText: 'Cari ID / Nama Pelanggan',
                    prefixIcon: Icon(Icons.search, color: AppColors.inkMuted),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderListView(_filteredOrders(null)),
                    _buildOrderListView(_filteredOrders(OrderStatus.diproses)),
                    _buildOrderListView(_filteredOrders(OrderStatus.selesai)),
                    _buildOrderListView(
                      _filteredOrders(OrderStatus.dibatalkan),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderListView(List<Order> orders) {
    // Status global: loading / error / kosong / isi.
    if (_data.isLoadingOrders && _data.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_data.ordersError != null && _data.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _data.ordersError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _data.loadOrders,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _data.loadOrders(),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const Center(
                child: Text(
                  'Belum ada pesanan',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _data.loadOrders(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) => _buildOrderCard(context, orders[index]),
      ),
    );
  }

  Color _badgeBg(OrderStatus status) {
    switch (status) {
      case OrderStatus.diproses:
        return AppColors.badgeWarningBg;
      case OrderStatus.selesai:
        return AppColors.badgeSuccessBg;
      case OrderStatus.dibatalkan:
        return AppColors.badgeErrorBg;
    }
  }

  Color _badgeText(OrderStatus status) {
    switch (status) {
      case OrderStatus.diproses:
        return AppColors.badgeWarningText;
      case OrderStatus.selesai:
        return AppColors.badgeSuccessText;
      case OrderStatus.dibatalkan:
        return AppColors.badgeErrorText;
    }
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final isExpanded = _expandedState[order.id] ?? true;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Status & Tombol Expand
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeBg(order.status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _badgeText(order.status),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () =>
                      setState(() => _expandedState[order.id] = !isExpanded),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Nama Pelanggan
            Text(
              order.customerLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // 3. Nomor ID
            Row(
              children: [
                Text(
                  'No. Pesanan: ${order.displayId}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.copy, size: 14, color: AppColors.inkMuted),
              ],
            ),
            const SizedBox(height: 4),

            // 4. Tanggal
            Text(
              order.dateLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),

            if (isExpanded) ...[
              const Divider(height: 24),
              ...order.items.map((item) => _buildOrderItem(order, item)),
              const Divider(height: 24),
              // 7. Ringkasan Transaksi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatRupiah(order.total),
                    style: AppTextStyles.priceTag.copyWith(fontSize: 14),
                  ),
                ],
              ),
              if (order.isPaid) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Metode', style: theme.textTheme.bodySmall),
                    Text(
                      order.paymentMethod?.label ?? '-',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 12),

            // 8. Tombol Aksi
            Row(
              children: [
                if (order.status == OrderStatus.diproses) ...[
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PosPaymentPage(order: order),
                          ),
                        );
                      },
                      child: const Text('Bayar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (order.status != OrderStatus.diproses) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptPage(order: order),
                          ),
                        );
                      },
                      child: const Text(
                        'Struk Pesanan',
                        style: TextStyle(color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.inkMuted),
                  onPressed: () => _showMoreMenu(context, order),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Order order, OrderItem item) {
    final isChecked = _checkedItems.contains('${order.id}|${item.productId}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (order.status == OrderStatus.diproses)
            Checkbox(
              value: isChecked,
              activeColor: AppColors.accent,
              onChanged: (_) => _toggleItem(order, item),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.qty}x ${item.name}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (item.note.isNotEmpty)
                  Text(
                    'Catatan: ${item.note}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatRupiah(item.subtotal),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
