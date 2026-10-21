/// Halaman Riwayat Penjualan: rekap transaksi lunas per periode
/// (harian / bulanan / tahunan / custom) beserta daftar transaksinya.
///
/// Data dari `GET /sales-history` (hanya order lunas). Kartu
/// "Produk Terjual" bisa diklik untuk membuka detail per produk.
library;

import 'package:flutter/material.dart';
import 'package:flutter_date_range_picker/flutter_date_range_picker.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../orders/order_detail_page.dart';
import 'period_pickers.dart';
import 'product_sales_page.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  AppData get _data => AppData.instance;

  // ---- Pilihan filter periode ----
  String _period = 'daily'; // daily | monthly | yearly | custom
  DateTime _dailyDate = _dateOnly(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _year = DateTime.now().year;
  DateRange? _customRange;

  /// Custom belum punya rentang — tunda pemuatan sampai dipilih.
  bool get _needCustomRange => _period == 'custom' && _customRange == null;

  @override
  void initState() {
    super.initState();
    // Halaman selalu dibuat ulang saat menu dipilih — muat periode default
    // (harian, hari ini) tiap kali dibuka supaya data segar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  /// Filter aktif dari pilihan user saat ini.
  SalesFilter get _currentFilter {
    switch (_period) {
      case 'monthly':
        return SalesFilter(period: 'monthly', month: _ym(_month));
      case 'yearly':
        return SalesFilter(period: 'yearly', year: '$_year');
      case 'custom':
        return SalesFilter(
          period: 'custom',
          startDate: _ymd(_customRange!.start),
          endDate: _ymd(_customRange!.end),
        );
      default:
        return SalesFilter(period: 'daily', date: _ymd(_dailyDate));
    }
  }

  void _load() {
    if (_needCustomRange) return;
    _data.loadSalesHistory(_currentFilter);
  }

  /// Buka halaman detail produk terjual dengan filter yang sama.
  void _openProductDetail() {
    final filter = _data.salesFilter;
    if (filter == null) return; // data belum pernah dimuat
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductSalesPage(filter: filter)),
    );
  }

  // ------------------------------------------------------------------
  // Buka picker periode (bottom sheet, lihat period_pickers.dart)
  // ------------------------------------------------------------------

  Future<void> _pickDaily() async {
    final picked = await showDailyPickerSheet(context, initial: _dailyDate);
    if (picked == null || !mounted) return;
    setState(() => _dailyDate = _dateOnly(picked));
    _load();
  }

  Future<void> _pickMonthly() async {
    final picked = await showMonthPickerSheet(context, selected: _month);
    if (picked == null || !mounted) return;
    setState(() => _month = picked);
    _load();
  }

  Future<void> _pickYearly() async {
    final picked = await showYearPickerSheet(context, selected: _year);
    if (picked == null || !mounted) return;
    setState(() => _year = picked);
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showCustomRangePickerSheet(context, initial: _customRange);
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _period = 'custom';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: AppData.instance,
      builder: (context, _) {
        final history = _data.salesHistory;
        final summary = history?.summary;

        return RefreshIndicator(
          onRefresh: () async {
            if (_needCustomRange) return;
            await _data.loadSalesHistory(_currentFilter);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildFilterCard(),
              const SizedBox(height: 16),
              if (_needCustomRange)
                _infoCard('Pilih rentang tanggal untuk melihat riwayat.')
              else ...[
                if (summary != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statCard(
                        title: 'Transaksi',
                        value: '${summary.transactionCount}',
                        icon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(width: 8),
                      _statCard(
                        title: 'Produk Terjual',
                        value: '${summary.productsSold}',
                        icon: Icons.chevron_right,
                        onTap: _openProductDetail,
                      ),
                      const SizedBox(width: 8),
                      _statCard(
                        title: 'Omzet',
                        value: formatRupiah(summary.omzet),
                        icon: Icons.payments_outlined,
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text('Daftar Transaksi', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                _buildTransactionList(history),
              ],
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Section 1: filter periode
  // ------------------------------------------------------------------

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Periode', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
            const SizedBox(height: 8),
            // 4 chip sama lebar dalam 1 baris (font 12) supaya "Custom"
            // tidak turun ke baris kedua di layar 6,3 inci.
            Row(
              children: [
                _periodChip('daily', 'Harian'),
                const SizedBox(width: 6),
                _periodChip('monthly', 'Bulanan'),
                const SizedBox(width: 6),
                _periodChip('yearly', 'Tahunan'),
                const SizedBox(width: 6),
                _periodChip('custom', 'Custom'),
              ],
            ),
            const SizedBox(height: 12),
            _buildPeriodValueField(),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    final selected = _period == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          setState(() => _period = value);
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodValueField() {
    switch (_period) {
      case 'monthly':
        return _dateField(
          label: 'Bulan',
          value: formatMonthYear(_month),
          onTap: _pickMonthly,
        );
      case 'yearly':
        return _dateField(
          label: 'Tahun',
          value: '$_year',
          onTap: _pickYearly,
        );
      case 'custom':
        return _dateField(
          label: 'Rentang Custom',
          value: _customRange == null
              ? 'Pilih rentang tanggal'
              : formatDateRange(_customRange!.start, _customRange!.end),
          muted: _customRange == null,
          onTap: _pickCustomRange,
        );
      default:
        return _dateField(
          label: 'Tanggal',
          value: formatDateShort(_dailyDate),
          onTap: _pickDaily,
        );
    }
  }

  /// Field tanggal read-only — tap membuka bottom sheet picker.
  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: AppColors.inkMuted,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: muted ? AppColors.inkMuted : AppColors.ink,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Section 2: kartu ringkasan (ukuran presisi: lebar sama rata,
  // tinggi tetap 84, struktur identik)
  // ------------------------------------------------------------------

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final tappable = onTap != null;
    return Expanded(
      child: SizedBox(
        height: 84,
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      Icon(
                        icon,
                        size: 16,
                        color: tappable ? AppColors.accent : AppColors.inkMuted,
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Section 3: daftar transaksi
  // ------------------------------------------------------------------

  Widget _buildTransactionList(SalesHistory? history) {
    if (_data.isLoadingSales && history == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_data.salesError != null) {
      return _errorCard(_data.salesError!, onRetry: _load);
    }

    if (history == null) return const SizedBox.shrink();

    if (history.orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tidak ada transaksi pada periode ini.',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.orders.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final order = history.orders[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // Klik transaksi -> halaman detail (lazy-load GET /orders/{id});
            // list sengaja ringan tanpa item supaya payload tetap kecil.
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailPage(orderId: order.id),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    order.code,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Text(
                  formatRupiah(order.total),
                  style: AppTextStyles.priceTag.copyWith(fontSize: 14),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${formatDateTime(order.createdAt)} • '
                '${order.paymentLabel} • '
                '${order.cashierName.isEmpty ? '-' : order.cashierName}',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.inkMuted,
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Kartu bantu (info / error)
  // ------------------------------------------------------------------

  Widget _infoCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message, {required VoidCallback onRetry}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Util tanggal
  // ------------------------------------------------------------------

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// YYYY-MM (tanpa dependency intl).
  static String _ym(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// YYYY-MM-DD (tanpa dependency intl).
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
