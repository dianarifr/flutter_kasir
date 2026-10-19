import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final paid = data.paidOrders;
        final revenue = data.todayRevenue;
        final avg = paid.isEmpty ? 0 : revenue ~/ paid.length;
        final critical = data.criticalStock;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(
                context,
                title: 'Penjualan Hari Ini',
                value: formatRupiah(revenue),
                icon: Icons.payments_outlined,
                subtext: '${paid.length} transaksi lunas',
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                context,
                title: 'Total Transaksi',
                value: '${paid.length} Nota',
                icon: Icons.receipt_outlined,
                subtext: paid.isEmpty
                    ? 'Belum ada transaksi lunas'
                    : 'Rata-rata ${formatRupiah(avg)} per nota',
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                context,
                title: 'Stok Kritis',
                value: '${critical.length} Bahan',
                icon: Icons.warning_amber_rounded,
                isWarning: true,
                subtext: critical.isEmpty
                    ? 'Semua stok aman'
                    : critical.map((s) => s.name).join(', '),
              ),
              const SizedBox(height: 28),

              Text('Aktivitas Terakhir', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),

              if (data.recentOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada aktivitas',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                )
              else
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.recentOrders.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final order = data.recentOrders[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.accent,
                          ),
                        ),
                        title: Text(
                          'Order #${order.id}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${order.itemsSummary} • ${order.isPaid ? order.paymentMethod?.label ?? 'Lunas' : order.status.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          formatRupiah(order.total),
                          style: AppTextStyles.priceTag.copyWith(fontSize: 14),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required String subtext,
    bool isWarning = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Icon(
                    icon,
                    size: 20,
                    color: isWarning ? AppColors.error : AppColors.inkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: isWarning
                    ? AppTextStyles.priceTag.copyWith(color: AppColors.error)
                    : AppTextStyles.priceTag,
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 12,
                  color: isWarning ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
