import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';
import '../pos/pos_payment_page.dart';
import '../receipt/receipt_page.dart';
import '../history/period_pickers.dart';
import 'cancel_order_dialog.dart';

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

  AppData get _data => AppData.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Muat order dari API setiap halaman dibuka (initState jalan ulang
    // setiap tab dipilih), memakai tanggal yang terakhir dipilih kasir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _data.loadOrdersForDate(_data.orderListDate);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// `true` bila daftar sedang menampilkan hari ini.
  bool get _isToday {
    final now = DateTime.now();
    final date = _data.orderListDate;
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Pilih tanggal lain lewat kalender (maksimal hari ini).
  Future<void> _pickDate() async {
    final picked = await showDailyPickerSheet(
      context,
      initial: _data.orderListDate,
    );
    if (picked == null || !mounted) return;
    await _data.loadOrdersForDate(picked);
  }

  Future<void> _backToToday() => _data.loadOrdersForDate(DateTime.now());

  /// Muat ulang tanggal yang sedang dipilih (pull-to-refresh / coba lagi).
  Future<void> _reload() => _data.loadOrdersForDate(_data.orderListDate);

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

  /// Batalkan pesanan lewat backend (stok bahan dikembalikan server).
  ///
  /// Order yang sudah selesai hanya bisa dibatalkan admin dan wajib
  /// punya keterangan; order `diproses` tetap seperti alur lama.
  Future<void> _cancelOrder(Order order) async {
    final messenger = ScaffoldMessenger.of(context);

    String? reason;
    final butuhAlasan = order.status == OrderStatus.selesai;
    if (butuhAlasan) {
      reason = await showCancelOrderDialog(context, order: order);
      if (reason == null || !mounted) return;
    }

    try {
      await _data.cancelOrder(order, reason: reason);
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

  /// Hapus satu item dari order (stok bahan item dikembalikan server,
  /// total kartu ikut menyesuaikan karena order diganti versi terbaru).
  Future<void> _removeItem(Order order, OrderItem item) async {
    // Diambil sebelum await dialog agar tidak menyentuh BuildContext
    // lintas async gap.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Item'),
        content: Text(
          'Hapus ${item.qty}x ${item.name} dari pesanan ini? '
          'Stok bahan akan dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _data.removeOrderItem(order, item);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Item dihapus, stok bahan dikembalikan.'),
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
                //
                // Order selesai/lunas hanya boleh dibatalkan admin dan
                // wajib mengisi keterangan (dialog di _cancelOrder).
                if (order.status == OrderStatus.diproses ||
                    (order.status == OrderStatus.selesai &&
                        order.isPaid &&
                        _data.isAdmin)) ...[
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
              _buildDateFilter(),
              // Bar pencarian
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

  /// Baris filter tanggal: menampilkan tanggal yang aktif dan jalan pintas
  /// kembali ke hari ini. Tanpa filter ini kasir hanya bisa melihat
  /// transaksi hari ini karena backend membatasi default ke hari ini.
  Widget _buildDateFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                ),
                child: Text(
                  _isToday
                      ? 'Hari ini, ${formatDateShort(_data.orderListDate)}'
                      : formatDateShort(_data.orderListDate),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          if (!_isToday) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: _backToToday, child: const Text('Hari ini')),
          ],
        ],
      ),
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
            OutlinedButton(onPressed: _reload, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Text(
                  _isToday
                      ? 'Belum ada pesanan'
                      : 'Belum ada pesanan pada tanggal ini',
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) =>
            _buildOrderCard(context, orders[index]),
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
            if (order.status == OrderStatus.dibatalkan &&
                order.cancelReason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Alasan batal: ${order.cancelReason}',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],

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
    // Hanya order yang masih diproses yang boleh item-nya dihapus;
    // backend menolak untuk order lunas/batal. itemId '-' berarti
    // backend belum mengirim id item (server lama).
    final canDelete =
        order.status == OrderStatus.diproses && item.itemId != '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
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
          // Tombol hapus item, berdempet dengan harga.
          if (canDelete)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              tooltip: 'Hapus item',
              onPressed: () => _removeItem(order, item),
            ),
        ],
      ),
    );
  }
}
