import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/utils/formatters.dart';
import 'pos_payment_page.dart';

class PosCheckoutPage extends StatefulWidget {
  const PosCheckoutPage({super.key});

  @override
  State<PosCheckoutPage> createState() => _PosCheckoutPageState();
}

class _PosCheckoutPageState extends State<PosCheckoutPage> {
  // 0: Bayar Langsung, 1: Buat Pesanan (Hanya 2 metode sesuai instruksi)
  int _selectedMethod = 0;
  bool _discountApplied = false;
  bool _extraFeeApplied = false;
  final Map<String, String> _notes = {};

  AppData get _data => AppData.instance;

  int get _discount => _discountApplied
      ? (_data.cartSubtotal * AppData.discountRate).round()
      : 0;
  int get _extraFee => _extraFeeApplied ? AppData.extraFeeAmount : 0;
  int get _total => _data.cartSubtotal - _discount + _extraFee;

  void _saveOrderOnly() {
    if (_data.cartItemCount == 0) {
      _showError('Keranjang masih kosong');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final order = _data.createOrder(
      discount: _discount,
      extraFee: _extraFee,
      notes: _notes,
    );

    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Pesanan ${order.id} disimpan, belum dibayar'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _payNow() {
    if (_data.cartItemCount == 0) {
      _showError('Keranjang masih kosong');
      return;
    }
    final order = _data.createOrder(
      discount: _discount,
      extraFee: _extraFee,
      notes: _notes,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => PosPaymentPage(order: order)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _editNote(String productId, String productName) async {
    final controller = TextEditingController(text: _notes[productId] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Catatan: $productName',
          style: const TextStyle(fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Contoh: tidak pakai saus',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.trim().isEmpty) {
        _notes.remove(productId);
      } else {
        _notes[productId] = result.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _data,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Metode Pemesanan (Hanya 2 Pilihan)
                      const Text(
                        'Metode Pemesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMethodCard(
                              index: 0,
                              title: 'Bayar Langsung',
                              subtitle:
                                  'Pembeli langsung melakukan pembayaran.',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMethodCard(
                              index: 1,
                              title: 'Buat Pesanan',
                              subtitle: 'Pembayaran dilakukan setelah proses pemesanan selesai.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 2. Diskon & Biaya Tambahan
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Diskon Transaksi (10%)'),
                              value: _discountApplied,
                              activeTrackColor: AppColors.accent,
                              onChanged: (val) =>
                                  setState(() => _discountApplied = val),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title: const Text('Biaya Tambahan (Rp 2.000)'),
                              value: _extraFeeApplied,
                              activeTrackColor: AppColors.accent,
                              onChanged: (val) =>
                                  setState(() => _extraFeeApplied = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. Rincian Pesanan
                      const Text(
                        'Rincian Pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ..._data.cart.entries.map((entry) {
                                final product = _data.products.firstWhere(
                                  (p) => p.id == entry.key,
                                );
                                final qty = entry.value;
                                final note = _notes[product.id] ?? '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            InkWell(
                                              onTap: () => _editNote(
                                                product.id,
                                                product.name,
                                              ),
                                              child: Text(
                                                note.isEmpty
                                                    ? '+ Tambah catatan'
                                                    : note,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: note.isEmpty
                                                      ? AppColors.accent
                                                      : AppColors.inkMuted,
                                                  fontStyle: note.isEmpty
                                                      ? FontStyle.normal
                                                      : FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${formatRupiah(product.price)} x $qty',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        formatRupiah(product.price * qty),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(height: 24),
                              _summaryRow(
                                'Subtotal',
                                formatRupiah(_data.cartSubtotal),
                              ),
                              if (_discount > 0)
                                _summaryRow(
                                  'Diskon (10%)',
                                  '-${formatRupiah(_discount)}',
                                  valueColor: AppColors.error,
                                ),
                              if (_extraFee > 0)
                                _summaryRow(
                                  'Biaya Tambahan',
                                  formatRupiah(_extraFee),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    formatRupiah(_total),
                                    style: AppTextStyles.priceTag.copyWith(
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tombol Aksi
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedMethod == 0 ? _payNow : _saveOrderOnly,
                    child: Text(
                      _selectedMethod == 0
                          ? 'Bayar Langsung'
                          : 'Simpan Pesanan',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required int index,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMethod == index;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? AppColors.accent : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
