import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/services/receipt_settings_service.dart';
import '../../core/theme/app_colors.dart';

/// Halaman pengaturan struk (menu drawer).
///
/// Saat ini isinya teks penutup struk yang bisa diubah per outlet.
/// Pengaturan printer akan menyusul di halaman yang sama saat fitur
/// cetak sungguhan tersedia.
class ReceiptSettingsPage extends StatefulWidget {
  const ReceiptSettingsPage({super.key});

  @override
  State<ReceiptSettingsPage> createState() => _ReceiptSettingsPageState();
}

class _ReceiptSettingsPageState extends State<ReceiptSettingsPage> {
  static const _maxLength = 160;

  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppData.instance.receiptFooter);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await AppData.instance.saveReceiptFooter(_controller.text);
      if (!mounted) return;
      // Tampilkan hasil normalisasi (mis. teks kosong -> default) supaya
      // yang terlihat sama dengan yang tersimpan.
      _controller.text = AppData.instance.receiptFooter;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Teks penutup struk disimpan'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan teks struk'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Isi kolom dengan teks bawaan. Belum tersimpan sampai "Simpan"
  /// ditekan supaya tidak ada perubahan tak sengaja.
  void _resetToDefault() {
    _controller.text = kDefaultReceiptFooter;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outletName = AppData.instance.currentOutlet?.name ?? '';
    // Teks kosong tetap dipratinjau sebagai default (sama dengan struk).
    final preview = ReceiptSettingsService.normalizeFooter(_controller.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teks Penutup Struk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tampil di bagian paling bawah struk. Boleh lebih dari '
                'satu baris. Kosongkan untuk memakai teks bawaan.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: kDefaultReceiptFooter,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pratinjau',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Nyemil Nyam',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (outletName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            outletName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      const Center(
                        child: Text(
                          '•••••',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        preview,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _isSaving ? null : _resetToDefault,
                  child: const Text('Kembalikan ke teks bawaan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}