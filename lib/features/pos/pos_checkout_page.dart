import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
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

  /// Id master charge yang diaktifkan kasir (pajak, diskon, dll —
  /// daftarnya dinamis dari backend).
  final Set<int> _selectedChargeIds = {};
  final Map<String, String> _notes = {};
  final TextEditingController _customerController = TextEditingController();
  bool _isSubmitting = false;

  AppData get _data => AppData.instance;

  @override
  void initState() {
    super.initState();
    // Charge dimuat cache-first: tampil instan dari data sesi/cache
    // persisten, disegarkan senyap di belakang layar bila usia data
    // lewat TTL (lihat AppData.loadCharges). Pelanggan tetap dimuat
    // langsung dari backend setiap checkout dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _data.loadCharges();
      _data.loadCustomers();
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  /// Bottom sheet pilih pelanggan (bisa juga ketik manual di text field).
  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String query = '';

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = _data.customers
                .where(
                  (c) => c.toLowerCase().contains(query.trim().toLowerCase()),
                )
                .toList();

            final content = SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Pilih Pelanggan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Cari pelanggan...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) => setSheetState(() => query = val),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  if (_data.customers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada pelanggan',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Pelanggan tidak ditemukan',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final customer = filtered[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surfaceAlt,
                              child: Icon(
                                Icons.person_outline,
                                size: 18,
                                color: AppColors.ink,
                              ),
                            ),
                            title: Text(customer),
                            onTap: () {
                              _customerController.text = customer;
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );

            // Angkat sheet di atas keyboard: kolom cari di dalam sheet
            // autofocus sehingga keyboard terbuka begitu sheet muncul;
            // tanpa padding ini sheet menempel di dasar layar dan
            // tertutup keyboard (kelihatan hanya setelah back).
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: content,
            );
          },
        );
      },
    );
  }

  /// Subtotal item di keranjang.
  int get _subtotal => _data.cartSubtotal;

  /// Baris charge yang diaktifkan: nominal sudah dihitung (bertanda —
  /// negatif = diskon). Perhitungan sama seperti backend supaya angka
  /// di layar dan di struk tidak beda.
  List<OrderChargeLine> get _activeChargeLines {
    return _data.charges
        .where((c) => _selectedChargeIds.contains(c.id))
        .map((c) {
          final amount = c.isPercentage
              ? _subtotal * c.value / 100
              : c.value;
          return OrderChargeLine(
            name: c.name,
            value: c.value,
            isPercentage: c.isPercentage,
            amount: c.isDiscount ? -amount : amount,
          );
        })
        .toList();
  }

  int get _discount => _activeChargeLines
      .where((c) => c.amount < 0)
      .fold(0, (sum, c) => sum + c.amount.abs().round());

  int get _extraFee => _activeChargeLines
      .where((c) => c.amount > 0)
      .fold(0, (sum, c) => sum + c.amount.round());

  int get _total => (_subtotal - _discount + _extraFee).clamp(0, 1 << 31);

  /// Peringatan bahan kurang/habis dari seluruh isi keranjang (non-blocking).
  List<String> get _cartIssues {
    final lines = <String>[];
    for (final entry in _data.cart.entries) {
      final matches = _data.products.where((p) => p.id == entry.key);
      if (matches.isEmpty) continue;
      final product = matches.first;

      for (final issue in _data.stockIssuesFor(product.id, entry.value)) {
        lines.add('${product.name}: $issue');
      }
    }
    return lines;
  }

  Future<void> _submit({required bool goToPayment}) async {
    if (_data.cartItemCount == 0) {
      _showError('Keranjang masih kosong');
      return;
    }
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final result = await _data.createOrder(
        customer: _customerController.text.trim(),
        chargeIds: _selectedChargeIds,
        notes: _notes,
      );

      // Peringatan bahan habis/minus dari backend — pesanan tetap tersimpan.
      // Ditampilkan DULU sebelum pindah halaman, karena halaman checkout
      // akan ditutup/diganti setelahnya.
      if (result.warnings.isNotEmpty && mounted) {
        await _showWarningsSheet(result.warnings);
      }

      if (goToPayment) {
        // Bayar langsung: lanjut ke halaman pembayaran dengan order dari server.
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => PosPaymentPage(order: result.order),
          ),
        );
      } else {
        navigator.popUntil((route) => route.isFirst);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Pesanan ${result.order.displayId} disimpan, belum dibayar',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Bottom sheet daftar bahan yang habis/minus setelah order disimpan.
  /// Menunggu sampai sheet ditutup (dipakai `await`).
  Future<void> _showWarningsSheet(List<StockWarning> warnings) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Peringatan Stok Bahan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 5,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w.label, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sisa bahan bisa minus. Transaksi tetap tersimpan.',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Mengerti'),
                ),
              ),
            ],
          ),
        ),
      ),
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
        final cartIssues = _cartIssues;

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
                      // 0. Peringatan bahan kurang/habis (non-blocking)
                      if (cartIssues.isNotEmpty) _buildStockWarningCard(cartIssues),
                      if (cartIssues.isNotEmpty) const SizedBox(height: 24),

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

                      // 2. Nama pelanggan (opsional) — tersimpan saat order dibuat.
                      const Text(
                        'Nama Pelanggan (Opsional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customerController,
                              decoration: const InputDecoration(
                                hintText: 'Nama Pembeli',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            onPressed: _showCustomerPicker,
                            child: const Text(
                              'Pilih',
                              style: TextStyle(color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Charge dinamis dari master_charges (pajak, diskon, dll)
                      Card(
                        child: Column(
                          children: [
                            if (_data.isLoadingCharges)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (_data.charges.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Tidak ada pajak/diskon yang tersedia',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              )
                            else ...[
                              for (final (index, charge)
                                  in _data.charges.indexed) ...[
                                if (index > 0) const Divider(height: 1),
                                SwitchListTile(
                                  title: Text(
                                    '${charge.name} (${charge.valueLabel})',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  value: _selectedChargeIds.contains(
                                    charge.id,
                                  ),
                                  activeTrackColor: AppColors.accent,
                                  onChanged: (val) => setState(() {
                                    val
                                        ? _selectedChargeIds.add(charge.id)
                                        : _selectedChargeIds.remove(charge.id);
                                  }),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4. Rincian Pesanan
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
                                final matches = _data.products.where(
                                  (p) => p.id == entry.key,
                                );
                                if (matches.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final product = matches.first;
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
                                formatRupiah(_subtotal),
                              ),
                              // Baris charge dinamis (diskon & biaya)
                              for (final line in _activeChargeLines)
                                _summaryRow(
                                  '${line.name}${line.isPercentage ? ' (${MasterCharge.trimValue(line.value)}%)' : ''}',
                                  line.amount < 0
                                      ? '-${formatRupiah(line.amount.abs().round())}'
                                      : formatRupiah(line.amount.round()),
                                  valueColor: line.amount < 0
                                      ? AppColors.error
                                      : null,
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
                    onPressed: _isSubmitting
                        ? null
                        : () => _submit(goToPayment: _selectedMethod == 0),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
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

  /// Kartu kuning berisi daftar bahan yang kurang/habis dari keranjang.
  Widget _buildStockWarningCard(List<String> issues) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text(
                'Bahan kurang/habis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $issue',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pesanan tetap bisa disimpan.',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
        ],
      ),
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
