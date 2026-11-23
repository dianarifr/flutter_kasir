/// Dialog wajib-alasan saat admin membatalkan transaksi yang sudah selesai.
///
/// Order yang masih `diproses` tetap dibatalkan lewat alur lama tanpa
/// dialog ini (tidak perlu keterangan). Dipakai bersama oleh Daftar
/// Pesanan dan Detail Transaksi supaya tampilannya konsisten.
library;

import 'package:flutter/material.dart';

import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Tampilkan dialog pembatalan. Mengembalikan alasan yang sudah di-trim,
/// atau `null` bila admin menutup dialog.
Future<String?> showCancelOrderDialog(
  BuildContext context, {
  required Order order,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CancelOrderDialog(order: order),
  );
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog({required this.order});

  final Order order;

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  static const _minLength = 3;

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().length >= _minLength;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return AlertDialog(
      title: const Text('Batalkan Pesanan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.displayId} • ${order.customerLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text('Total ${formatRupiah(order.total)}'),
            const SizedBox(height: 12),
            const Text(
              'Stok bahan akan dikembalikan dan transaksi ini tidak lagi '
              'dihitung sebagai omzet.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Keterangan pembatalan',
                hintText: 'Contoh: pelanggan membatalkan pesanan',
                helperText: 'Wajib diisi, minimal 3 karakter.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kembali'),
        ),
        TextButton(
          onPressed: _canSubmit
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text(
            'Batalkan Pesanan',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
