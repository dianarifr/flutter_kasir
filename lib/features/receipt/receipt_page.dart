import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';

class ReceiptPage extends StatelessWidget {
  final Order order;

  const ReceiptPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Nama outlet dari sesi yang sedang login.
    final outletName = AppData.instance.currentOutlet?.name ?? 'Nyemil Nyam';

    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header toko
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 32,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nyemil Nyam',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            outletName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // Info struk
                    _infoRow('No. Struk', order.displayId),
                    const SizedBox(height: 4),
                    _infoRow('Tanggal', formatDate(order.createdAt)),
                    const SizedBox(height: 4),
                    _infoRow('Pelanggan', order.customerLabel),
                    const SizedBox(height: 4),
                    _infoRow('Antrian', '${order.queueNumber}'),
                    const Divider(height: 24),

                    // Rincian item
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.qty}x ${item.name}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  formatRupiah(item.subtotal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (item.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  top: 2,
                                ),
                                child: Text(
                                  'Catatan: ${item.note}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // Ringkasan biaya — charge dinamis dari backend
                    // (pajak/diskon/biaya lain), fallback rekap agregat.
                    _infoRow('Subtotal', formatRupiah(order.subtotal)),
                    if (order.charges.isNotEmpty)
                      ...order.charges.map(
                        (charge) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _infoRow(
                            charge.isPercentage
                                ? '${charge.name} (${MasterCharge.trimValue(charge.value)}%)'
                                : charge.name,
                            charge.amount < 0
                                ? '-${formatRupiah(charge.amount.abs().round())}'
                                : formatRupiah(charge.amount.round()),
                            valueColor:
                                charge.amount < 0 ? AppColors.error : null,
                          ),
                        ),
                      )
                    else ...[
                      if (order.discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _infoRow(
                            'Diskon',
                            '-${formatRupiah(order.discount)}',
                            valueColor: AppColors.error,
                          ),
                        ),
                      if (order.extraFee > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _infoRow(
                            'Biaya Tambahan',
                            formatRupiah(order.extraFee),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          formatRupiah(order.total),
                          style: AppTextStyles.priceTag.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Status & info pembayaran
                    Center(
                      child: order.status == OrderStatus.dibatalkan
                          ? _cancelBadge()
                          : _statusBadge(order.isPaid),
                    ),
                    const SizedBox(height: 12),
                    if (order.isPaid) ...[
                      _infoRow('Metode', order.paymentMethod?.label ?? '-'),
                      if (order.paymentMethod == PaymentMethod.tunai) ...[
                        const SizedBox(height: 4),
                        _infoRow(
                          'Tunai diterima',
                          formatRupiah(order.cashGiven),
                        ),
                        const SizedBox(height: 4),
                        _infoRow('Kembalian', formatRupiah(order.changeGiven)),
                      ],
                      if (order.paymentMethod == PaymentMethod.campuran) ...[
                        const SizedBox(height: 4),
                        _infoRow('Tunai', formatRupiah(order.splitCash)),
                        const SizedBox(height: 4),
                        _infoRow('Non Tunai', formatRupiah(order.splitNonCash)),
                      ],
                    ] else
                      const Text(
                        'Pesanan ini belum dibayar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Terima kasih telah berbelanja',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Struk dikirim ke printer (demo)'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Cetak Struk'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(bool paid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: paid ? AppColors.badgeSuccessBg : AppColors.badgeWarningBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paid ? 'LUNAS' : 'BELUM DIBAYAR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: paid ? AppColors.badgeSuccessText : AppColors.badgeWarningText,
        ),
      ),
    );
  }

  Widget _cancelBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.badgeErrorBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'DIBATALKAN',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppColors.badgeErrorText,
        ),
      ),
    );
  }
}
