import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';

/// Caption otomatis saat struk dibagikan. Nama outlet tidak diulang
/// bila kosong atau sama dengan nama brand.
String buildReceiptCaption(String outletName) {
  final outlet = outletName.trim();
  if (outlet.isEmpty || outlet.toLowerCase() == 'nyemil nyam') {
    return 'Halo! Nyemil Nyam mengirimkan struk untuk kamu';
  }
  return 'Halo! Nyemil Nyam $outlet mengirimkan struk untuk kamu';
}

class ReceiptPage extends StatefulWidget {
  final Order order;

  const ReceiptPage({super.key, required this.order});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  /// Menandai area struk yang diubah jadi gambar saat "Bagikan".
  final GlobalKey _receiptKey = GlobalKey();

  bool _isSharing = false;

  Order get order => widget.order;

  /// Caption otomatis saat struk dibagikan.
  String _shareCaption() =>
      buildReceiptCaption(AppData.instance.currentOutlet?.name ?? '');

  /// `share_plus` hanya bisa mengirim file di Android, iOS, macOS, dan
  /// Windows 10 RS5+. Linux tidak mendukung berbagi file sama sekali,
  /// jadi tombolnya diberi penjelasan alih-alih gagal tanpa alasan.
  ///
  /// Memakai `defaultTargetPlatform` (bukan `dart:io`) supaya tetap aman
  /// dikompilasi untuk web.
  bool get _platformSupportsFileShare =>
      defaultTargetPlatform != TargetPlatform.linux;

  /// Ubah area struk ([_receiptKey]) menjadi PNG. `null` bila boundary
  /// belum terpasang.
  ///
  /// `RenderRepaintBoundary.toImage()` melempar assertion di mode debug
  /// bila layer boundary masih perlu paint, jadi tunggu satu frame penuh
  /// dulu. Frame dipaksa lewat `scheduleFrame()` — `endOfFrame` saja bisa
  /// menggantung bila tidak ada frame yang dijadwalkan.
  Future<Uint8List?> _captureReceiptPng() async {
    final boundary =
        _receiptKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (boundary.debugNeedsPaint) {
        await _waitForNextFrame();
      }
      try {
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data?.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      } on AssertionError {
        // Layer baru berubah ukuran: tunggu frame berikutnya lalu ulang.
        if (attempt == 2) rethrow;
      }
    }
    return null;
  }

  /// Tunggu satu frame yang benar-benar dijadwalkan.
  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  Future<void> _shareReceipt() async {
    if (_isSharing) return;

    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;

    // Linux dan Windows lama tidak mendukung berbagi FILE di share_plus
    // (hanya teks). Tanpa cek ini, tombol akan "gagal" tanpa alasan jelas
    // saat dijalankan via `flutter run -d linux`.
    if (!_platformSupportsFileShare) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Bagikan struk sebagai gambar hanya tersedia di Android. '
            'Di desktop, struk bisa dicetak lewat tombol Cetak Struk.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSharing = true);
    try {
      final bytes = await _captureReceiptPng();
      if (bytes == null) {
        throw StateError('Area struk belum siap direkam.');
      }

      await SharePlus.instance.share(
        ShareParams(
          text: _shareCaption(),
          subject: 'Struk ${order.displayId}',
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['struk-${order.displayId}.png'],
          // Wajib untuk iPad/macOS agar share sheet punya anchor.
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e, st) {
      // Selalu log detailnya — tanpa ini penyebab asli (plugin tidak
      // terdaftar, gagal tulis cache, dsb) tidak pernah kelihatan.
      debugPrint('Bagikan struk gagal: $e\n$st');

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kDebugMode
                ? 'Gagal membagikan struk: $e'
                : 'Gagal membagikan struk. Coba lagi.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Nama outlet dari sesi yang sedang login.
    final outletName = AppData.instance.currentOutlet?.name ?? 'Nyemil Nyam';

    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // Latar opak supaya PNG hasil bagikan tidak transparan di
            // sudut kartu (beberapa aplikasi merendernya jadi hitam).
            child: RepaintBoundary(
              key: _receiptKey,
              child: Container(
                color: AppColors.bg,
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header toko
                        Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 32,
                                color: AppColors.accent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nyemil Nyam',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                outletName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),

                        // Info struk
                        _infoRow('No. Struk', order.displayId),
                        const SizedBox(height: 4),
                        _infoRow('Tanggal', formatDate(order.createdAt)),
                        const SizedBox(height: 4),
                        _infoRow('Pelanggan', order.customerLabel),
                        const SizedBox(height: 4),
                        _infoRow('Antrian', '${order.queueNumber}'),
                        const Divider(height: 24),

                        // Rincian item
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.qty}x ${item.name}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(item.subtotal),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.note.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      top: 2,
                                    ),
                                    child: Text(
                                      'Catatan: ${item.note}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),

                        // Ringkasan biaya — charge dinamis dari backend
                        // (pajak/diskon/biaya lain), fallback rekap agregat.
                        _infoRow('Subtotal', formatRupiah(order.subtotal)),
                        if (order.charges.isNotEmpty)
                          ...order.charges.map(
                            (charge) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _infoRow(
                                charge.isPercentage
                                    ? '${charge.name} (${MasterCharge.trimValue(charge.value)}%)'
                                    : charge.name,
                                charge.amount < 0
                                    ? '-${formatRupiah(charge.amount.abs().round())}'
                                    : formatRupiah(charge.amount.round()),
                                valueColor: charge.amount < 0
                                    ? AppColors.error
                                    : null,
                              ),
                            ),
                          )
                        else ...[
                          if (order.discount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _infoRow(
                                'Diskon',
                                '-${formatRupiah(order.discount)}',
                                valueColor: AppColors.error,
                              ),
                            ),
                          if (order.extraFee > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _infoRow(
                                'Biaya Tambahan',
                                formatRupiah(order.extraFee),
                              ),
                            ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              formatRupiah(order.total),
                              style: AppTextStyles.priceTag.copyWith(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Status & info pembayaran
                        Center(
                          child: order.status == OrderStatus.dibatalkan
                              ? _cancelBadge()
                              : _statusBadge(order.isPaid),
                        ),
                        const SizedBox(height: 12),
                        if (order.isPaid) ...[
                          _infoRow(
                            'Metode',
                            order.paymentMethod?.label ?? '-',
                          ),
                          if (order.paymentMethod == PaymentMethod.tunai) ...[
                            const SizedBox(height: 4),
                            _infoRow(
                              'Tunai diterima',
                              formatRupiah(order.cashGiven),
                            ),
                            const SizedBox(height: 4),
                            _infoRow(
                              'Kembalian',
                              formatRupiah(order.changeGiven),
                            ),
                          ],
                          if (order.paymentMethod ==
                              PaymentMethod.campuran) ...[
                            const SizedBox(height: 4),
                            _infoRow('Tunai', formatRupiah(order.splitCash)),
                            const SizedBox(height: 4),
                            _infoRow(
                              'Non Tunai',
                              formatRupiah(order.splitNonCash),
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),
                        // Teks penutup — bisa diubah di menu Pengaturan Struk.
                        Center(
                          child: Text(
                            AppData.instance.receiptFooter,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSharing
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Struk dikirim ke printer (demo)',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                      child: const Text('Cetak Struk'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSharing ? null : _shareReceipt,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Bagikan'),
                    ),
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

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(bool paid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: paid ? AppColors.badgeSuccessBg : AppColors.badgeWarningBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paid ? 'LUNAS' : 'BELUM DIBAYAR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: paid ? AppColors.badgeSuccessText : AppColors.badgeWarningText,
        ),
      ),
    );
  }

  Widget _cancelBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.badgeErrorBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'DIBATALKAN',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppColors.badgeErrorText,
        ),
      ),
    );
  }
}