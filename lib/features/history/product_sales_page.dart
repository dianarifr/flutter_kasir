/// Halaman detail produk terjual — drill-down dari kartu "Produk Terjual"
/// di Riwayat Penjualan. Data dari `GET /sales-history/products`.
library;

import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class ProductSalesPage extends StatefulWidget {
  /// Filter periode yang sama dengan halaman Riwayat Penjualan.
  final SalesFilter filter;

  const ProductSalesPage({super.key, required this.filter});

  @override
  State<ProductSalesPage> createState() => _ProductSalesPageState();
}

class _ProductSalesPageState extends State<ProductSalesPage> {
  AppData get _data => AppData.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _data.loadProductSales(widget.filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk Terjual')),
      body: ListenableBuilder(
        listenable: AppData.instance,
        builder: (context, _) {
          final products = _data.productSales;
          final totalQty = products.fold<int>(0, (sum, p) => sum + p.qty);
          final totalRevenue = products.fold<int>(0, (sum, p) => sum + p.revenue);

          return RefreshIndicator(
            onRefresh: () => _data.loadProductSales(widget.filter),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_outlined,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Periode: ${widget.filter.displayLabel}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_data.isLoadingProductSales && products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_data.productSalesError != null)
                  _errorCard(_data.productSalesError!)
                else if (products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Tidak ada produk terjual pada periode ini.',
                        style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                      ),
                    ),
                  )
                else ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            product.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            formatRupiah(product.revenue),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${product.qty} terjual',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$totalQty terjual • ${formatRupiah(totalRevenue)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _errorCard(String message) {
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
            OutlinedButton(
              onPressed: () => _data.loadProductSales(widget.filter),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
