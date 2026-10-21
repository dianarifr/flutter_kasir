/// Halaman detail satu transaksi — dipakai bersama oleh Riwayat
/// Penjualan dan Dashboard (Aktivitas Terakhir).
///
/// Tampilannya sama seperti kartu pesanan di Daftar Pesanan, tapi tanpa
/// tombol aksi (struk pesanan, bayar, titik tiga).
///
/// Dua mode sumber data:
/// - [order] terisi   → render langsung (dashboard; order dari `/orders`
///   sudah membawa items, tidak perlu fetch ulang).
/// - [order] kosong   → lazy-load `GET /orders/{id}` saat halaman dibuka
///   (riwayat penjualan; list `/sales-history` sengaja ringan tanpa item).
library;

import 'package:flutter/material.dart';

import '../../core/data/models.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';

class OrderDetailPage extends StatefulWidget {
  /// Id order untuk mode lazy-load; diabaikan bila [order] terisi.
  final String orderId;

  /// Order yang sudah lengkap (opsional) — lewati fetch bila terisi.
  final Order? order;

  const OrderDetailPage({super.key, required this.orderId, this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _order;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    if (_order == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await OrderService.instance.fetchOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _order = order);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Tidak dapat memuat detail transaksi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _order == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _OrderDetailCard(order: _order!),
            ),
    );
  }
}

/// Kartu detail transaksi — struktur & gaya sama seperti kartu pesanan
/// di Daftar Pesanan (badge, pelanggan, no. pesanan, item + catatan,
/// total, metode) minus tombol aksi.
class _OrderDetailCard extends StatelessWidget {
  const _OrderDetailCard({required this.order});

  final Order order;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Badge status.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(height: 12),

            // 2. Nama pelanggan.
            Text(
              order.customerLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // 3. Nomor pesanan.
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

            // 4. Tanggal + nomor antrian.
            Text(
              order.dateLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),

            const Divider(height: 24),

            // 5. Daftar item + catatan per item.
            ...order.items.map(_buildItemRow),
            const Divider(height: 24),

            // 6. Ringkasan: total + metode pembayaran.
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
        ),
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.qty}x ${item.name}', style: const TextStyle(fontSize: 13)),
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

/// Tampilan gagal memuat dengan tombol coba lagi.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
