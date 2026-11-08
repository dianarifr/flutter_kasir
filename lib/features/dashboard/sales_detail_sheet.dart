/// Modal "Rincian Penjualan" — muncul saat kartu "Penjualan Hari Ini"
/// di dashboard diklik: breakdown tunai vs non tunai + total.
///
/// Sumber angka mengikuti kartu supaya rinciannya selalu cocok dengan
/// nominal headline:
/// - shift aktif  -> ringkasan shift (`GET /shifts/current`);
/// - tanpa shift  -> dihitung dari order lunas hari ini (per outlet).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Susun teks rincian penjualan untuk dibagikan ke WhatsApp.
///
/// Format final (sesuai permintaan user):
/// ```
/// 06/11/2026
/// Tunai = 83.000
/// Non tunai = 93.000
///
/// Total = 176.000
/// ```
String buildSalesShareText({
  required DateTime date,
  required int tunai,
  required int nonTunai,
  required int total,
}) {
  return '${formatDateNumeric(date)}\n'
      'Tunai = ${formatAngka(tunai)}\n'
      'Non tunai = ${formatAngka(nonTunai)}\n'
      '\n'
      'Total = ${formatAngka(total)}';
}

/// Tampilkan modal rincian penjualan.
Future<void> showSalesDetailSheet(BuildContext context, AppData data) {
  return showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SalesDetailSheet(data: data),
  );
}

class _SalesDetailSheet extends StatelessWidget {
  const _SalesDetailSheet({required this.data});

  final AppData data;

  /// Porsi tunai dari daftar order lunas: metode tunai utuh + porsi
  /// tunai dari pembayaran campuran (angka sama dengan aturan laci).
  static int _cashOf(List<Order> paid) {
    var total = 0;
    for (final order in paid) {
      if (order.paymentMethod == PaymentMethod.tunai) {
        total += order.total;
      } else if (order.paymentMethod == PaymentMethod.campuran) {
        total += order.splitCash;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final shift = data.currentShift;
    final summary = shift?.summary;

    // Mode shift: angka dari backend. Mode tanpa shift: hitung lokal
    // dari order lunas hari ini milik outlet yang login.
    final bool fromShift = shift != null && summary != null;
    final int tunai = fromShift ? summary.cashTotal : _cashOf(data.paidOrders);
    final int total = fromShift ? summary.salesTotal : data.todayRevenue;
    final int nonTunai = total - tunai;
    final int trx = fromShift
        ? summary.transactionCount
        : data.paidOrders.length;

    // Tanggal periode yang dilaporkan: tanggal mulai shift bila ada
    // (aman untuk shift lewat tengah malam), selain itu tanggal hari ini.
    final shareText = buildSalesShareText(
      date: fromShift ? shift.startTime : DateTime.now(),
      tunai: tunai,
      nonTunai: nonTunai,
      total: total,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rincian Penjualan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                _ShareWhatsAppButton(text: shareText),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              fromShift
                  ? 'Shift mulai ${formatTime(shift.startTime)}'
                  : 'Hari ini • shift belum dibuka',
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.money_outlined,
              label: 'Tunai',
              hint: fromShift
                  ? 'Masuk laci shift'
                  : 'Pembayaran tunai hari ini',
              value: formatRupiah(tunai),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.credit_card_outlined,
              label: 'Non Tunai',
              hint: 'QRIS, transfer, metode lain',
              value: formatRupiah(nonTunai),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            _DetailRow(
              icon: Icons.receipt_long_outlined,
              label: 'Total Penjualan',
              hint: '$trx transaksi lunas',
              value: formatRupiah(total),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol kecil di kanan judul modal: bagikan rincian ke WhatsApp.
///
/// Membuka WhatsApp (lewat deep link `wa.me`, jadi tetap jalan meski
/// WhatsApp tidak terpasang) dengan teks rincian sudah terisi. Bila
/// tidak ada aplikasi yang bisa membuka link, teks disalin ke clipboard
/// supaya kasir tetap bisa menempel manual.
class _ShareWhatsAppButton extends StatelessWidget {
  const _ShareWhatsAppButton({required this.text});

  final String text;

  Future<void> _share(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;

    // Fallback: salin teks agar user tinggal menempel di WhatsApp.
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rincian disalin — tempel di WhatsApp')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Bagikan ke WhatsApp',
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _share(context),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(Icons.share_outlined, size: 18, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Baris rincian: icon + label (+ keterangan kecil) di kiri, nominal
/// di kanan.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              Text(
                hint,
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
