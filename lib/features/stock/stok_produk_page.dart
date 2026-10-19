import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';

/// Halaman stok produk (porsi) pada outlet user yang sedang login.
///
/// Data diambil dari API `/products/stock` (stok produk dihitung
/// backend dari stok komponen via resep/BOM).
class StokProdukPage extends StatefulWidget {
  const StokProdukPage({super.key});

  @override
  State<StokProdukPage> createState() => _StokProdukPageState();
}

class _StokProdukPageState extends State<StokProdukPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final items = data.productStocks;

        // Muat sekali saat pertama dibuka (belum ada data & belum error).
        if (items.isEmpty && !data.isLoadingStock && data.stockError == null) {
          data.loadProductStock(withDetail: true);
        }

        if (data.isLoadingStock && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.stockError != null) {
          return _ErrorView(message: data.stockError!);
        }

        // Filter lokal berdasarkan nama produk (case-insensitive).
        final filtered = _query.isEmpty
            ? items
            : items
                  .where(
                    (item) =>
                        item.name.toLowerCase().contains(_query.toLowerCase()),
                  )
                  .toList();

        return Column(
          children: [
            _SearchField(
              controller: _searchController,
              hintText: 'Cari produk...',
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada data produk.',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    )
                  : filtered.isEmpty
                  ? _EmptySearchView(query: _query)
                  : RefreshIndicator(
                      onRefresh: () => data.loadProductStock(withDetail: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _StockCard(item: filtered[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Kolom pencarian dengan tombol hapus query.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Tampilan saat query pencarian tidak menemukan apa pun.
class _EmptySearchView extends StatelessWidget {
  const _EmptySearchView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 40,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada hasil untuk "$query".',
            style: const TextStyle(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Kartu stok satu produk.
class _StockCard extends StatelessWidget {
  const _StockCard({required this.item});

  final ProductStock item;

  Color get _statusColor {
    if (!item.isStockTracked) return AppColors.inkMuted;
    if (item.isCritical) return AppColors.error;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final critical = item.isStockTracked && item.isCritical;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: critical ? AppColors.error : AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(item.price.round()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                  if (item.bottleneckComponent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Terbatas oleh: ${item.bottleneckComponent}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              item.isStockTracked ? '${item.stock} porsi' : 'N/A',
              style: AppTextStyles.priceTag.copyWith(
                fontSize: 16,
                color: critical ? AppColors.error : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan error dengan tombol coba lagi.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

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
          FilledButton.icon(
            onPressed: () =>
                AppData.instance.loadProductStock(withDetail: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
