import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';
import '../orders/order_detail_page.dart';
import '../shift/shift_sheets.dart';
import 'sales_detail_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppData get _data => AppData.instance;

  @override
  void initState() {
    super.initState();
    // initState jalan ulang setiap tab dipilih, jadi data dashboard
    // selalu segar: omzet dari order API, stok kritis dari stok bahan,
    // dan ringkasan shift aktif (angka live sejak shift dibuka).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _data.loadOrders();
      _data.loadComponentStock();
      _data.loadCurrentShift();
    });
  }

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

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              data.loadOrders(),
              data.loadComponentStock(),
              data.loadCurrentShift(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSalesCard(context, data),
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

                if (data.isLoadingOrders && data.orders.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (data.recentOrders.isEmpty)
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
                          // Klik aktivitas -> detail transaksi. Order dari
                          // `/orders` sudah membawa items, jadi halaman
                          // detail langsung render tanpa fetch ulang.
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailPage(
                                orderId: order.id,
                                order: order,
                              ),
                            ),
                          ),
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
                            'Order #${order.displayId}',
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
          ),
        );
      },
    );
  }

  /// Kartu pertama "Penjualan Hari Ini" — dua mode:
  ///
  /// * Shift aktif   : angka = penjualan sejak shift dibuka (live dari
  ///   API shift) + tombol "Setor" untuk menutup shift.
  /// * Tanpa shift   : angka fallback kalender hari ini + tombol
  ///   "Buka Shift" (modal awal) — shift wajib sebelum melayani.
  Widget _buildSalesCard(BuildContext context, AppData data) {
    final shift = data.currentShift;
    final summary = shift?.summary;

    return Card(
      child: InkWell(
        // Kartu bisa diklik untuk melihat rincian tunai vs non tunai.
        borderRadius: BorderRadius.circular(12),
        onTap: () => showSalesDetailSheet(context, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Penjualan Hari Ini',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Nominal sesuai shift aktif (ringkasan dari backend,
              // dijamin satu outlet). Tanpa shift: fallback omzet
              // hari ini milik outlet user login.
              Text(
                formatRupiah(summary?.salesTotal ?? data.todayRevenue),
                style: AppTextStyles.priceTag,
              ),
              const SizedBox(height: 4),
              Text(
                shift != null && summary != null
                    ? '${summary.transactionCount} transaksi • '
                        'Shift mulai ${formatTime(shift.startTime)}'
                    : data.paidOrders.isEmpty
                        ? 'Belum ada transaksi • Shift belum dibuka'
                        : '${data.paidOrders.length} transaksi lunas • '
                            'Shift belum dibuka',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      shift != null ? AppColors.success : AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: shift != null
                    ? FilledButton.icon(
                        onPressed: () => showCloseShiftSheet(context),
                        icon: const Icon(Icons.savings_outlined, size: 18),
                        label: const Text('Setor'),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => showOpenShiftSheet(context),
                        icon: const Icon(
                          Icons.play_circle_outline,
                          size: 18,
                        ),
                        label: const Text('Buka Shift'),
                      ),
              ),
            ],
          ),
        ),
      ),
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
