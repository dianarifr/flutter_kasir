import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';
import '../receipt/receipt_page.dart';

class PosPaymentPage extends StatefulWidget {
  final Order order;

  const PosPaymentPage({super.key, required this.order});

  @override
  State<PosPaymentPage> createState() => _PosPaymentPageState();
}

class _PosPaymentPageState extends State<PosPaymentPage> {
  final _cashController = TextEditingController();
  final _changeController = TextEditingController();
  final _splitCashController = TextEditingController();
  final _splitNonCashController = TextEditingController();

  // 0: Tunai, 1: Non Tunai, 2: Pembayaran Campuran
  int _selectedPaymentMethod = 0;
  int _cashGiven = 0;
  int _splitCash = 0;
  int _splitNonCash = 0;
  bool _isSubmitting = false;

  AppData get _data => AppData.instance;
  int get _total => widget.order.total;
  int get _change => _cashGiven - _total;
  int get _splitTotal => _splitCash + _splitNonCash;
  int get _splitRemaining => _total - _splitTotal;

  /// Shortcut nominal dinamis mengikuti total pembayaran:
  /// - total < 50rb -> selalu 50rb & 100rb
  /// - 50rb <= total < 100rb -> 100rb
  /// - total >= 100rb -> kelipatan 100rb di atasnya
  ///   (total 120rb -> 200rb & 300rb)
  List<int> get _cashShortcuts {
    const nominal50 = 50000;
    const nominal100 = 100000;
    if (_total < nominal50) return [nominal50, nominal100];
    if (_total < nominal100) return [nominal100];
    final base = (_total / nominal100).floor() * nominal100;
    return [base + nominal100, base + 2 * nominal100];
  }

  @override
  void initState() {
    super.initState();
    _cashGiven = _total;
    _cashController.text = _total.toString();
    _syncChangeField();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _changeController.dispose();
    _splitCashController.dispose();
    _splitNonCashController.dispose();
    super.dispose();
  }

  /// Terapkan nominal tunai lalu segarkan field Kembalian.
  void _applyCash(int value) {
    setState(() {
      _cashGiven = value;
      _syncChangeField();
    });
  }

  /// Sinkronkan isi field Kembalian dengan nilai [_change] terkini.
  /// Uang kurang ditandai minus (warna merah) tanpa kata tambahan agar
  /// nominalnya tetap mudah dibaca.
  void _syncChangeField() {
    _changeController.text = _change < 0
        ? '-${formatRupiah(-_change)}'
        : formatRupiah(_change);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _confirm() async {
    if (_selectedPaymentMethod == 0 && _cashGiven < _total) {
      _showError('Jumlah uang tunai kurang dari total pembayaran');
      return;
    }
    if (_selectedPaymentMethod == 2 && _splitRemaining != 0) {
      _showError('Nominal pembayaran campuran belum mencapai total');
      return;
    }
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Kirim ke backend; kembalian dihitung server, order terbaru dipakai struk.
      final paid = await _data.payOrder(
        widget.order,
        method: PaymentMethod.values[_selectedPaymentMethod],
        cashGiven: _selectedPaymentMethod == 0 ? _cashGiven : 0,
        splitCash: _selectedPaymentMethod == 2 ? _splitCash : 0,
        splitNonCash: _selectedPaymentMethod == 2 ? _splitNonCash : 0,
      );

      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute(builder: (_) => ReceiptPage(order: paid)),
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pembayaran Berhasil Disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Pembayaran', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(_total),
                    style: AppTextStyles.priceTag.copyWith(
                      color: AppColors.success,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metode Pembayaran (Chips)
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPaymentChip('Tunai', Icons.money, 0),
                        const SizedBox(width: 8),
                        _buildPaymentChip('Non Tunai', Icons.credit_card, 1),
                        const SizedBox(width: 8),
                        _buildPaymentChip(
                          'Pembayaran Campuran',
                          Icons.swap_horiz,
                          2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Opsi 1: Tunai
                  if (_selectedPaymentMethod == 0) ...[
                    const Text(
                      'Silakan masukkan uang yang diberikan oleh pembeli.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    // Dua kolom dalam 1 baris: Nominal Bayar (bisa
                    // diketik) dan Kembalian (readonly, mengikuti
                    // nominal bayar).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nominal Bayar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _cashController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: 'Rp ',
                                ),
                                onChanged: (val) =>
                                    _applyCash(int.tryParse(val) ?? 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kembalian',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _changeController,
                                readOnly: true,
                                showCursor: false,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _change < 0
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surfaceAlt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Shortcut nominal dinamis mengikuti total pembayaran.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _cashController.text = _total.toString();
                              _applyCash(_total);
                            },
                            child: const Text('Uang Pas'),
                          ),
                          for (final nominal in _cashShortcuts) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                _cashController.text = '$nominal';
                                _applyCash(nominal);
                              },
                              child: Text(formatRupiah(nominal)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Opsi 2: Non Tunai (EDC/QRIS)
                  if (_selectedPaymentMethod == 1) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Silakan lakukan pembayaran melalui mesin EDC atau pindai QRIS yang tersedia.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],

                  // Opsi 3: Pembayaran Campuran
                  if (_selectedPaymentMethod == 2) ...[
                    const Text(
                      'Silakan isi nominal pembayaran untuk masing-masing metode pembayaran yang digunakan.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${formatRupiah(_splitTotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sisa yang harus dibayar: ${formatRupiah(_splitRemaining < 0 ? 0 : _splitRemaining)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _splitRemaining > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _splitCashController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tunai',
                              prefixText: 'Rp ',
                            ),
                            onChanged: (val) => setState(
                              () => _splitCash = int.tryParse(val) ?? 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _splitNonCashController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Non Tunai',
                              prefixText: 'Rp ',
                            ),
                            onChanged: (val) => setState(
                              () => _splitNonCash = int.tryParse(val) ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Tombol Konfirmasi
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _confirm,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Konfirmasi Pembayaran'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(String label, IconData icon, int index) {
    final isSelected = _selectedPaymentMethod == index;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.bg : AppColors.ink,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.bg : AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppColors.accent,
      checkmarkColor: AppColors.bg,
      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
      onSelected: (selected) => setState(() => _selectedPaymentMethod = index),
    );
  }
}
