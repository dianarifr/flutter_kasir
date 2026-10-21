import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Halaman Sisa Stok bahan/kemasan pada outlet user yang sedang login.
///
/// Data diambil dari API `/components/stock` — sisa stok tiap komponen
/// beserta tipe (bahan/kemasan), satuan dan ambang minimum yang diatur
/// admin. Bisa difilter per tipe lewat chip di bawah pencarian.
class StokBahanPage extends StatefulWidget {
  const StokBahanPage({super.key});

  @override
  State<StokBahanPage> createState() => _StokBahanPageState();
}

class _StokBahanPageState extends State<StokBahanPage> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Filter tipe aktif: `all` | `bahan` | `kemasan`.
  String _typeFilter = 'all';

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

        // Filter lokal: nama (case-insensitive) + tipe komponen.
        final query = _query.toLowerCase();
        final filtered = items.where((item) {
          final matchQuery =
              query.isEmpty || item.name.toLowerCase().contains(query);
          final matchType =
              _typeFilter == 'all' || item.type == _typeFilter;
          return matchQuery && matchType;
        }).toList();

        return Column(
          children: [
            _SearchField(
              controller: _searchController,
              hintText: 'Cari bahan...',
              onChanged: (value) => setState(() => _query = value),
            ),
            _TypeFilterBar(
              selected: _typeFilter,
              onChanged: (value) => setState(() => _typeFilter = value),
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
                  ? _EmptySearchView(query: _query, filtered: _typeFilter != 'all')
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

/// Bar filter tipe komponen — 3 chip sama lebar dalam 1 baris, gaya
/// pill sama seperti chip periode di Riwayat Penjualan.
class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _chip('all', 'Semua'),
          const SizedBox(width: 8),
          _chip('bahan', 'Bahan'),
          const SizedBox(width: 8),
          _chip('kemasan', 'Kemasan'),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final isSelected = selected == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : AppColors.ink,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
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

/// Tampilan saat pencarian / filter tipe tidak menemukan apa pun.
class _EmptySearchView extends StatelessWidget {
  const _EmptySearchView({required this.query, this.filtered = false});

  final String query;

  /// `true` bila filter tipe aktif — pesan disesuaikan.
  final bool filtered;

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
            filtered
                ? 'Tidak ada hasil untuk filter ini.'
                : 'Tidak ada hasil untuk "$query".',
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
                  // Nama + badge tipe berdempet; badge turun ke baris
                  // berikutnya bila nama kepanjangan.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      // Badge tipe komponen: Bahan / Kemasan.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.type == 'kemasan'
                              ? AppColors.badgeWarningBg
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: item.type == 'kemasan'
                                ? AppColors.badgeWarningText
                                : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
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
