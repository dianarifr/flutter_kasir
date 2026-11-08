/// Test tombol "bagikan rincian ke WhatsApp" di modal Rincian Penjualan:
///
/// - Format teks share harus persis seperti yang diminta user
///   (`06/11/2026` / `Tunai = 83.000` / `Non tunai = 93.000` / kosong /
///   `Total = 176.000`), jadi helper-nya diuji terpisah dari UI.
/// - Modal harus menampilkan tombol share kecil di kanan judul.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/utils/formatters.dart';
import 'package:flutter_kasir/features/dashboard/sales_detail_sheet.dart';

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showSalesDetailSheet(context, AppData.instance),
              child: const Text('PANGGIL-MODAL'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('buildSalesShareText', () {
    test('mengikuti format yang diminta (tanpa prefiks Rp)', () {
      final text = buildSalesShareText(
        date: DateTime(2026, 11, 6),
        tunai: 83000,
        nonTunai: 93000,
        total: 176000,
      );

      expect(
        text,
        '06/11/2026\n'
        'Tunai = 83.000\n'
        'Non tunai = 93.000\n'
        '\n'
        'Total = 176.000',
      );
    });

    test('tanggal selalu dd/MM/yyyy untuk hari & bulan satu digit', () {
      final text = buildSalesShareText(
        date: DateTime(2026, 1, 5),
        tunai: 0,
        nonTunai: 0,
        total: 0,
      );

      expect(text.startsWith('05/01/2026\n'), isTrue);
      expect(text, contains('Tunai = 0'));
      expect(text, contains('Total = 0'));
    });
  });

  group('formatter pendukung', () {
    test('formatAngka memakai pemisah ribuan tanpa "Rp"', () {
      expect(formatAngka(83000), '83.000');
      expect(formatAngka(176000), '176.000');
      expect(formatAngka(0), '0');
      expect(formatAngka(-1250), '-1.250');
    });

    test('formatRupiah tetap sama seperti sebelumnya', () {
      expect(formatRupiah(1250000), 'Rp 1.250.000');
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(-1250), '-Rp 1.250');
    });

    test('formatDateNumeric menghasilkan dd/MM/yyyy', () {
      expect(formatDateNumeric(DateTime(2026, 11, 6)), '06/11/2026');
      expect(formatDateNumeric(DateTime(2026, 1, 5, 23, 59)), '05/01/2026');
    });
  });

  testWidgets('modal Rincian Penjualan punya tombol share di kanan judul', (
    tester,
  ) async {
    await _pumpHost(tester);

    await tester.tap(find.text('PANGGIL-MODAL'));
    await tester.pumpAndSettle();

    expect(find.text('Rincian Penjualan'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byTooltip('Bagikan ke WhatsApp'), findsOneWidget);
  });
}