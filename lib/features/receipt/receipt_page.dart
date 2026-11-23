/// Halaman struk setelah pembayaran (dan cetak ulang dari Daftar Pesanan).
///
/// Isi struk ada di [ReceiptDocument]; aksi cetak/bagikan di
/// [receipt_actions.dart] — keduanya dipakai juga oleh detail transaksi.
library;

import 'package:flutter/material.dart';

import '../../core/data/models.dart';
import 'receipt_actions.dart';
import 'receipt_document.dart';

export 'receipt_actions.dart' show buildReceiptCaption;

class ReceiptPage extends StatefulWidget {
  final Order order;

  const ReceiptPage({super.key, required this.order});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  /// Menandai area struk yang diubah jadi gambar saat "Bagikan".
  final GlobalKey _receiptKey = GlobalKey();

  /// Menonaktifkan tombol lain selama proses bagikan berjalan.
  bool _isSharing = false;

  Order get order => widget.order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: RepaintBoundary(
              key: _receiptKey,
              child: ReceiptDocument(order: order),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: PrintReceiptButton(enabled: !_isSharing)),
                  const SizedBox(width: 8),
                  ShareReceiptButton(
                    order: order,
                    boundaryKey: _receiptKey,
                    onBusyChanged: (busy) =>
                        setState(() => _isSharing = busy),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSharing
                      ? null
                      : () {
                          Navigator.of(context).popUntil(
                            (route) => route.isFirst,
                          );
                        },
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}