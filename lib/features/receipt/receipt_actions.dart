/// Aksi struk yang dipakai bersama: cetak (masih demo) dan bagikan sebagai
/// gambar PNG lewat share sheet bawaan OS.
///
/// Semua logika teknis — render struk, konversi PNG, cek platform, caption —
/// dikumpulkan di sini supaya halaman struk dan detail transaksi berperilaku
/// identik tanpa duplikasi.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import 'receipt_document.dart';

/// Caption otomatis saat struk dibagikan. Nama outlet tidak diulang
/// bila kosong atau sama dengan nama brand.
String buildReceiptCaption(String outletName) {
  final outlet = outletName.trim();
  if (outlet.isEmpty || outlet.toLowerCase() == 'nyemil nyam') {
    return 'Halo! Nyemil Nyam mengirimkan struk untuk kamu';
  }
  return 'Halo! Nyemil Nyam $outlet mengirimkan struk untuk kamu';
}

/// `share_plus` hanya bisa mengirim file di Android, iOS, macOS, dan
/// Windows 10 RS5+. Linux tidak mendukung berbagi file sama sekali,
/// jadi tombolnya diberi penjelasan alih-alih gagal tanpa alasan.
///
/// Memakai `defaultTargetPlatform` (bukan `dart:io`) supaya tetap aman
/// dikompilasi untuk web.
bool get platformSupportsFileShare =>
    defaultTargetPlatform != TargetPlatform.linux;

/// Ubah area [boundaryKey] menjadi PNG. `null` bila boundary belum terpasang.
///
/// `RenderRepaintBoundary.toImage()` melempar assertion di mode debug bila
/// layer boundary masih perlu paint, jadi tunggu satu frame penuh dulu.
/// Frame dipaksa lewat `scheduleFrame()` — `endOfFrame` saja bisa menggantung
/// bila tidak ada frame yang dijadwalkan.
Future<Uint8List?> captureBoundaryPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
  if (boundary == null) return null;

  for (var attempt = 0; attempt < 3; attempt++) {
    if (boundary.debugNeedsPaint) {
      await _waitForNextFrame();
    }
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
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

/// Tampilkan pesan singkat di SnackBar.
void _toast(ScaffoldMessengerState messenger, String message, {bool ok = false}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ),
  );
}

/// Bagikan hasil capture ke share sheet OS lengkap dengan caption.
///
/// Melempar error yang sudah diberi konteks agar pemanggil cukup
/// menampilkannya. Pengecekan platform dilakukan pemanggil lewat
/// [platformSupportsFileShare].
Future<void> shareReceiptPng({
  required Uint8List bytes,
  required Order order,
  required String caption,
  Rect? origin,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: caption,
      subject: 'Struk ${order.displayId}',
      files: [XFile.fromData(bytes, mimeType: 'image/png')],
      fileNameOverrides: ['struk-${order.displayId}.png'],
      // Wajib untuk iPad/macOS agar share sheet punya anchor.
      sharePositionOrigin: origin,
    ),
  );
}

/// Tombol "Bagikan": merender struk [order] jadi gambar lalu membuka share
/// sheet. Dipakai di halaman struk maupun detail transaksi.
///
/// Bila [boundaryKey] diberikan, gambar diambil dari area yang sudah tampil
/// di layar. Tanpa itu, struk dirender sendiri di luar layar (overlay)
/// sehingga halaman pemanggil tidak perlu menampilkan struknya.
class ShareReceiptButton extends StatefulWidget {
  const ShareReceiptButton({
    super.key,
    required this.order,
    this.boundaryKey,
    this.onBusyChanged,
    this.expanded = true,
    this.iconOnly = false,
  });

  final Order order;

  /// Area struk yang sudah terpasang di layar. `null` = render offscreen.
  final GlobalKey? boundaryKey;

  /// Dipanggil saat proses bagikan mulai/selesai, berguna untuk
  /// menonaktifkan tombol lain di baris yang sama.
  final ValueChanged<bool>? onBusyChanged;

  /// `true` = melebar memenuhi ruang (untuk tombol berlabel).
  final bool expanded;

  /// `true` = hanya ikon (dipakai di AppBar).
  final bool iconOnly;

  @override
  State<ShareReceiptButton> createState() => _ShareReceiptButtonState();
}

class _ShareReceiptButtonState extends State<ShareReceiptButton> {
  bool _isSharing = false;

  Order get order => widget.order;

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _isSharing = value);
    widget.onBusyChanged?.call(value);
  }

  Future<void> _share() async {
    if (_isSharing) return;

    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    if (!platformSupportsFileShare) {
      _toast(
        messenger,
        'Bagikan struk sebagai gambar hanya tersedia di Android. '
        'Di desktop, struk bisa dicetak lewat tombol Cetak Struk.',
      );
      return;
    }

    _setBusy(true);
    OverlayEntry? offscreen;
    try {
      final key = widget.boundaryKey ?? GlobalKey();
      if (widget.boundaryKey == null) {
        offscreen = _buildOffscreenEntry(key);
        Overlay.of(context, rootOverlay: true).insert(offscreen);
        await _waitForNextFrame();
      }

      final bytes = await captureBoundaryPng(key);
      if (bytes == null) {
        throw StateError('Area struk belum siap direkam.');
      }

      await shareReceiptPng(
        bytes: bytes,
        order: order,
        caption: buildReceiptCaption(AppData.instance.currentOutlet?.name ?? ''),
        origin: origin,
      );
      // Share sheet sudah ditutup user.
      if (!mounted) return;
      _setBusy(false);
    } catch (e, st) {
      // Selalu log detailnya — tanpa ini penyebab asli (plugin tidak
      // terdaftar, gagal render, dsb) tidak pernah kelihatan.
      debugPrint('Bagikan struk gagal: $e\n$st');
      _toast(
        messenger,
        kDebugMode
            ? 'Gagal membagikan struk: $e'
            : 'Gagal membagikan struk. Coba lagi.',
      );
      _setBusy(false);
    } finally {
      offscreen?.remove();
    }
  }

  /// Struk yang dirender di luar layar: lebarnya disamakan dengan struk di
  /// halaman struk supaya proporsi gambarnya sama persis.
  OverlayEntry _buildOffscreenEntry(GlobalKey key) {
    return OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: 0,
        width: 400,
        child: RepaintBoundary(
          key: key,
          child: Material(
            type: MaterialType.transparency,
            child: ReceiptDocument(order: order),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _isSharing ? null : _share;

    if (widget.iconOnly) {
      return IconButton(
        onPressed: onPressed,
        tooltip: 'Bagikan struk',
        icon: _isSharing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.share_outlined),
      );
    }

    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: _isSharing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share_outlined, size: 16),
      label: const Text('Bagikan'),
    );

    return widget.expanded ? Expanded(child: button) : button;
  }
}

/// Tombol "Cetak Struk".
///
/// Cetak sungguhan belum tersedia (menunggu printer Bluetooth), jadi
/// tombolnya memberi pesan demo yang sama di semua halaman yang memakainya.
/// [onDisabledChanged] dipakai agar tombol ini ikut nonaktif saat proses
/// bagikan berjalan.
class PrintReceiptButton extends StatelessWidget {
  const PrintReceiptButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Struk dikirim ke printer (demo)'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          : null,
      child: const Text('Cetak Struk'),
    );
  }
}