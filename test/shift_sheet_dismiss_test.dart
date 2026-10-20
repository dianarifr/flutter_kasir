/// Regresi untuk laporan "modal tidak bisa dismiss":
///
/// Modal "Buka Shift" muncul dari dua tempat — gate saat buka app dan
/// pantulan saat menekan menu Kasir tanpa shift. Keduanya HARUS bisa
/// ditutup (tap di luar / drag / tombol back): kewajiban shift kini
/// ditekan di gerbang menu Kasir, bukan dengan mengunci modal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_kasir/features/shift/shift_sheets.dart';

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showOpenShiftSheet(context),
              child: const Text('PANGGIL-MODAL'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('modal Buka Shift bisa ditutup dengan tap di luar', (
    tester,
  ) async {
    await _pumpHost(tester);

    await tester.tap(find.text('PANGGIL-MODAL'));
    await tester.pumpAndSettle();
    // Dua teks "Buka Shift" dalam SATU modal: judul + label tombol.
    expect(find.text('Buka Shift'), findsNWidgets(2));

    // Tap jauh di atas sheet (area barrier).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Buka Shift'), findsNothing);
  });

  testWidgets('modal yang ditutup tidak meninggalkan modal kembar', (
    tester,
  ) async {
    await _pumpHost(tester);

    // Buka -> tutup -> buka lagi: hanya boleh ada satu modal.
    await tester.tap(find.text('PANGGIL-MODAL'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PANGGIL-MODAL'));
    await tester.pumpAndSettle();
    expect(find.text('Buka Shift'), findsNWidgets(2));
  });
}
