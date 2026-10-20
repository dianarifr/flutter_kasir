import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';
import 'pos_checkout_page.dart';

class PosCatalogPage extends StatefulWidget {
  const PosCatalogPage({super.key});

  @override
  State<PosCatalogPage> createState() => _PosCatalogPageState();
}

class _PosCatalogPageState extends State<PosCatalogPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  AppData get _data => AppData.instance;

  @override
  void initState() {
    super.initState();
    // Produk dimuat cache-first: tampil instan dari data sesi/cache
    // persisten, disegarkan senyap di belakang layar bila usia data
    // lewat TTL (lihat AppData.loadProducts). Stok produk ikut dimuat
    // DENGAN detail komponen supaya kasir bisa diperingatkan saat
    // menambah produk yang bahannya kurang/habis.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_data.isLoadingProducts) _data.loadProducts();
      if (!_data.isLoadingStock) _data.loadProductStock(withDetail: true);
    });
  }

  /// Tambah ke keranjang + peringatan non-blocking bila bahan penyusun
  /// produk kurang/habis. Pesanan tetap bisa dilanjutkan — kasir hanya
  /// diberi tahu.
  void _addProduct(String productId) {
    final newQty = _data.cartQty(productId) + 1;
    _data.addToCart(productId);

    final issues = _data.stockIssuesFor(productId, newQty);
    if (issues.isEmpty) return;

    final matches = _data.products.where((p) => p.id == productId);
    final productName = matches.isEmpty ? '-' : matches.first.name;
    _showStockWarningDialog(productName, issues);
  }

  void _showStockWarningDialog(String productName, List<String> issues) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stok Bahan Kurang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 5,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pesanan tetap bisa dilanjutkan.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _data,
      builder: (context, _) {
        final query = _query.trim().toLowerCase();
        final products = query.isEmpty
            ? _data.products
            : _data.products
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

        // State katalog: loading / error / kosong / hasil pencarian / grid.
        Widget body;
        if (_data.products.isEmpty) {
          if (_data.isLoadingProducts) {
            body = const Center(child: CircularProgressIndicator());
          } else if (_data.productsError != null) {
            body = _buildRefreshable(_buildErrorView(_data.productsError!));
          } else {
            body = _buildRefreshable(
              const Center(
                child: Text(
                  'Belum ada produk',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ),
            );
          }
        } else if (products.isEmpty) {
          body = _buildRefreshable(
            Center(
              child: Text(
                'Tidak ada hasil untuk "$_query"',
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            ),
          );
        } else {
          body = RefreshIndicator(
            onRefresh: () => _data.loadProducts(force: true),
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.70,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  _buildProductCard(context, products[index]),
            ),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              // Bar pencarian
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val),
                  decoration: InputDecoration(
                    hintText: 'Cari Nama/SKU/Barcode',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.inkMuted,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      // Tombol X: bersihkan pencarian (muncul saat ada teks),
                      // di sebelah kiri tombol scan barcode.
                      children: [
                        if (_query.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.inkMuted,
                            ),
                            tooltip: 'Bersihkan pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                        const Icon(
                          Icons.qr_code_scanner,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Grid produk 2 kolom (atau state loading/error/kosong)
              Expanded(child: body),

              // Bottom bar keranjang
              if (_data.cartItemCount > 0) _buildBottomBar(context),
            ],
          ),
        );
      },
    );
  }

  /// Bungkus konten dengan pull-to-refresh (muat ulang produk dari API).
  Widget _buildRefreshable(Widget child) {
    return RefreshIndicator(
      onRefresh: () => _data.loadProducts(force: true),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  /// Tampilan saat gagal memuat produk dari API.
  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.inkMuted),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _data.loadProducts(force: true),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 2),
              Text(
                formatRupiah(_data.cartSubtotal),
                style: AppTextStyles.priceTag.copyWith(fontSize: 18),
              ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PosCheckoutPage(),
                ),
              );
            },
            child: Text('Beli (${_data.cartItemCount})'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final qty = _data.cartQty(product.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar produk dari API; placeholder bila kosong/gagal dimuat
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.imageUrl == null
                    ? Container(
                        color: AppColors.surfaceAlt,
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      )
                    : Image.network(
                        product.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Placeholder saat gambar sedang dimuat (download/decode).
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: AppColors.surfaceAlt,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surfaceAlt,
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              formatRupiah(product.price),
              style: AppTextStyles.priceTag.copyWith(
                color: AppColors.success,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            // Tombol Tambah vs Selector Plus/Min/Ketik
            if (qty == 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.accent),
                  ),
                  onPressed: () => _addProduct(product.id),
                  child: const Text(
                    'Tambah',
                    style: TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
              )
            else
              _buildQuantitySelector(product.id, qty),
          ],
        ),
      ),
    );
  }

  // Widget Tombol (-) [Angka Input] (+)
  Widget _buildQuantitySelector(String productId, int qty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tombol Minus (-)
        SizedBox(
          width: 36,
          height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _data.decrementCart(productId),
            child: const Icon(Icons.remove, size: 16, color: AppColors.accent),
          ),
        ),

        // Input Jumlah Angka (Bisa Diketik)
        SizedBox(
          width: 48,
          height: 36,
          child: TextFormField(
            key: ValueKey('qty_${productId}_$qty'),
            initialValue: qty.toString(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) =>
                _data.setCartQty(productId, int.tryParse(val) ?? 0),
          ),
        ),

        // Tombol Plus (+)
        SizedBox(
          width: 36,
          height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _addProduct(productId),
            child: const Icon(Icons.add, size: 16, color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}
