import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Halaman stok bahan (komponen) pada outlet user yang sedang login.
///
/// Data diambil dari API `/components/stock` — sisa stok mentah
/// tiap bahan beserta satuan dan ambang minimum yang diatur admin.
class StokBahanPage extends StatefulWidget {
  const StokBahanPage({super.key});

  @override
  State<StokBahanPage> createState() => _StokBahanPageState();
}

class _StokBahanPageState extends State<StokBahanPage> {
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
        final items = data.componentStocks;

        // Muat sekali saat pertama dibuka (belum ada data & belum error).
        if (items.isEmpty &&
            !data.isLoadingComponents &&
            data.componentError == null) {
          data.loadComponentStock();
        }

        if (data.isLoadingComponents && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.componentError != null) {
          return _ErrorView(message: data.componentError!);
        }

        // Filter lokal berdasarkan nama bahan (case-insensitive).
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
              hintText: 'Cari bahan...',
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada data bahan.',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    )
                  : filtered.isEmpty
                  ? _EmptySearchView(query: _query)
                  : RefreshIndicator(
                      onRefresh: () => data.loadComponentStock(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _ComponentCard(item: filtered[index]),
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

/// Kartu stok satu bahan/komponen.
class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.item});

  final ComponentStock item;

  @override
  Widget build(BuildContext context) {
    final critical = item.isCritical;

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
                Icons.egg_outlined,
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
                    'Min. ${item.minStock} ${item.unit}',
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
                      color: critical ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${item.currentStock} ${item.unit}',
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
            onPressed: () => AppData.instance.loadComponentStock(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
