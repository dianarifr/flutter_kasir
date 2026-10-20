/// Modal shift kasir: "Buka Shift" (input modal awal) dan "Setor"
/// (tutup shift: keterangan + uang disetor + catatan). Modal Buka
/// Shift dipakai juga sebagai gate wajib setelah login/auto-login.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/app_data.dart';
import '../../core/data/models.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Tampilkan modal "Buka Shift".
///
/// Modal selalu bisa ditutup (tap di luar, drag ke bawah, tombol
/// back) — user boleh menundanya dan membuka shift lewat kartu di
/// Dashboard. Kewajiban shift untuk melayani ditekan di gerbang menu
/// Kasir (MainShell), bukan dengan mengunci modal ini.
Future<void> showOpenShiftSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _OpenShiftSheet(),
  );
}

/// Tampilkan modal "Setor" untuk menutup shift aktif.
Future<void> showCloseShiftSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _CloseShiftSheet(),
  );
}

/// Ambil angka murni dari isi TextField nominal (buang semua non-digit).
int? _parseNominal(String raw) =>
    int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));

class _OpenShiftSheet extends StatefulWidget {
  const _OpenShiftSheet();

  @override
  State<_OpenShiftSheet> createState() => _OpenShiftSheetState();
}

class _OpenShiftSheetState extends State<_OpenShiftSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nominal = _parseNominal(_controller.text);
    if (nominal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modal awal wajib diisi.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppData.instance.openShift(nominal);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka shift, coba lagi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AppData.instance;
    final outletName = data.currentOutlet?.name ?? '-';
    final kasirName = data.currentUser?.name ?? '-';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const Text(
              'Buka Shift',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$outletName • $kasirName',
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Masukkan modal awal uang di laci sebelum melayani '
              'transaksi. Boleh diisi 0 bila laci masih kosong.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Modal awal',
                hintText: '0',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Buka Shift'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseShiftSheet extends StatefulWidget {
  const _CloseShiftSheet();

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  late final Shift _shift;
  late final ShiftSummary? _summary;
  late final TextEditingController _setorController;
  late final TextEditingController _notesController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _shift = AppData.instance.currentShift!;
    _summary = _shift.summary;
    // Default uang disetor = perkiraan isi laci (modal awal + tunai);
    // kasir boleh mengubah bila uang di laci tidak pas.
    _setorController = TextEditingController(
      text: '${_summary?.expectedCash ?? _shift.startingCash}',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _setorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _expected => _summary?.expectedCash ?? _shift.startingCash;

  int get _disetor => _parseNominal(_setorController.text) ?? 0;

  int get _selisih => _disetor - _expected;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final closed = await AppData.instance.closeShift(
        _disetor,
        _notesController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);

      final selisih = closed.selisih ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selisih == 0
                ? 'Shift ditutup. Uang laci pas.'
                : 'Shift ditutup. Selisih ${selisih > 0 ? 'lebih' : 'kurang'} '
                    '${formatRupiah(selisih.abs())}.',
          ),
          backgroundColor:
              selisih == 0 ? AppColors.success : AppColors.error,
        ),
      );

      // Segarkan daftar aktivitas & angka fallback di dashboard.
      AppData.instance.loadOrders();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menutup shift, coba lagi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? AppColors.ink : AppColors.inkMuted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const Text(
              'Setor & Tutup Shift',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Shift mulai ${formatTime(_shift.startTime)}',
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _infoRow(
                    'Modal awal',
                    formatRupiah(_shift.startingCash),
                  ),
                  _infoRow(
                    'Total penjualan',
                    formatRupiah(summary?.salesTotal ?? 0),
                  ),
                  _infoRow(
                    'Tunai terkumpul',
                    formatRupiah(summary?.cashTotal ?? 0),
                  ),
                  _infoRow('Total di laci', formatRupiah(_expected), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _setorController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Uang disetor',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selisih == 0
                  ? 'Selisih: Rp0 (pas)'
                  : _selisih > 0
                      ? 'Selisih: lebih ${formatRupiah(_selisih)}'
                      : 'Selisih: kurang ${formatRupiah(_selisih.abs())}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _selisih == 0 ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Mis. uang kembalian, laci tidak pas, dll',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Tutup Shift'),
            ),
          ],
        ),
      ),
    );
  }
}
