/// Test halaman struk & Pengaturan Struk:
/// - teks penutup mengikuti pengaturan yang disimpan,
/// - struk punya 3 tombol (Cetak, Bagikan, Selesai),
/// - tombol Bagikan memberi pesan jelas di platform yang tidak bisa
///   mengirim file (Linux desktop).
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/services/receipt_settings_service.dart';
import 'package:flutter_kasir/features/receipt/receipt_page.dart';
import 'package:flutter_kasir/features/receipt/receipt_settings_page.dart';

Order _order() => Order(
  id: '1',
  code: 'INV001',
  createdAt: DateTime(2026, 11, 8),
  queueNumber: 1,
  items: const [
    OrderItem(
      itemId: '1',
      productId: '1',
      name: 'Dimsum',
      price: 15000,
      qty: 2,
    ),
  ],
  subtotal: 30000,
  isPaid: true,
  status: OrderStatus.selesai,
  paymentMethod: PaymentMethod.tunai,
  cashGiven: 50000,
  changeGiven: 20000,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppData.instance.saveReceiptFooter(kDefaultReceiptFooter);
  });

  testWidgets('struk tampil dengan teks bawaan dan 3 tombol', (tester) async {
    await _pump(tester, ReceiptPage(order: _order()));

    expect(find.text(kDefaultReceiptFooter), findsOneWidget);
    expect(find.text('Cetak Struk'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mengubah teks penutup langsung tampil di struk', (
    tester,
  ) async {
    await _pump(tester, const ReceiptSettingsPage());

    await tester.enterText(find.byType(TextField), 'Terima kasih, sampai jumpa!');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(AppData.instance.receiptFooter, 'Terima kasih, sampai jumpa!');

    await _pump(tester, ReceiptPage(order: _order()));
    expect(find.text('Terima kasih, sampai jumpa!'), findsOneWidget);
  });

  testWidgets('teks kosong kembali ke bawaan saat disimpan', (tester) async {
    await _pump(tester, const ReceiptSettingsPage());

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(AppData.instance.receiptFooter, kDefaultReceiptFooter);
  });

  testWidgets('Bagikan di desktop menjelaskan kenapa tidak bisa', (
    tester,
  ) async {
    // share_plus tidak bisa mengirim FILE di Linux; tombol harus memberi
    // penjelasan, bukan diam atau gagal tanpa alasan.
    //
    // Override wajib direset di dalam body test: binding memeriksa
    // debug variable sebelum tearDown dijalankan.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pump(tester, ReceiptPage(order: _order()));

      await tester.tap(find.text('Bagikan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('hanya tersedia di Android'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('area struk benar-benar bisa dirender jadi PNG', (tester) async {
    await _pump(tester, ReceiptPage(order: _order()));

    // Ambil RepaintBoundary struk (bukan boundary milik Scaffold).
    final boundaries = tester
        .widgetList<RepaintBoundary>(find.byType(RepaintBoundary))
        .toList();
    expect(boundaries, isNotEmpty);

    RenderRepaintBoundary? target;
    for (final widget in boundaries) {
      final render = widget.key == null
          ? null
          : (tester.element(find.byWidget(widget)).renderObject
                as RenderRepaintBoundary?);
      if (render != null) target = render;
    }
    expect(target, isNotNull, reason: 'boundary struk harus ada');

    await tester.runAsync(() async {
      final image = await target!.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      expect(data, isNotNull);
      final bytes = data!.buffer.asUint8List();
      expect(bytes.length, greaterThan(1000));
      // Magic number PNG: \x89 P N G
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}