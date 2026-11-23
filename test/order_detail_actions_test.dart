/// Test tombol "Cetak Struk" & "Bagikan" di halaman Detail Transaksi
/// (Riwayat Penjualan dan Dashboard memakai halaman yang sama).
///
/// Gambar yang dibagikan adalah **struk resmi** yang dirender di luar layar,
/// jadi test ini juga memastikan mekanisme render offscreen menghasilkan PNG
/// yang benar — bukan sekadar memastikan tombol bisa ditekan.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/features/orders/order_detail_page.dart';
import 'package:flutter_kasir/features/receipt/receipt_actions.dart';
import 'package:flutter_kasir/features/receipt/receipt_document.dart';

Order _order() => Order(
  id: '1',
  code: 'INV001',
  createdAt: DateTime(2026, 11, 8),
  queueNumber: 12,
  items: const [
    OrderItem(
      itemId: '1',
      productId: '1',
      name: 'Dimsum Mentai',
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
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setClient(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {'receipt_footer': null},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  testWidgets('detail transaksi menampilkan tombol cetak dan bagikan', (
    tester,
  ) async {
    await _pump(tester, OrderDetailPage(orderId: '1', order: _order()));
    await tester.pumpAndSettle();

    expect(find.text('Detail Transaksi'), findsOneWidget);
    expect(find.text('Cetak Struk'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cetak Struk memberi pesan demo yang sama seperti di struk', (
    tester,
  ) async {
    await _pump(tester, OrderDetailPage(orderId: '1', order: _order()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cetak Struk'));
    await tester.pump();

    expect(find.text('Struk dikirim ke printer (demo)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol tidak tampil saat detail gagal dimuat', (tester) async {
    // Tanpa `order` -> halaman lazy-load. Selama data belum ada, tombol
    // cetak/bagikan tidak boleh muncul (tidak ada struk untuk diproses).
    await _pump(tester, const OrderDetailPage(orderId: '99'));
    await tester.pump();
    expect(find.text('Cetak Struk'), findsNothing);
    expect(find.text('Bagikan'), findsNothing);

    await tester.pumpAndSettle();
    // Mock mengembalikan JSON yang bukan bentuk order -> tampil error.
    expect(find.text('Cetak Struk'), findsNothing);
    expect(find.text('Bagikan'), findsNothing);
  });

  testWidgets('Bagikan di desktop memberi penjelasan, tidak crash', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pump(tester, OrderDetailPage(orderId: '1', order: _order()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bagikan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('hanya tersedia di Android'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('struk yang dirender offscreen menghasilkan PNG valid', (
    tester,
  ) async {
    final key = GlobalKey();

    await _pump(
      tester,
      Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              final entry = OverlayEntry(
                builder: (_) => Positioned(
                  left: -10000,
                  top: 0,
                  width: 400,
                  child: RepaintBoundary(
                    key: key,
                    child: Material(
                      type: MaterialType.transparency,
                      child: ReceiptDocument(order: _order()),
                    ),
                  ),
                ),
              );
              Overlay.of(tester.element(find.byType(TextButton)), rootOverlay: true)
                  .insert(entry);
            },
            child: const Text('SIAPKAN'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('SIAPKAN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    Uint8List? png;
    await tester.runAsync(() async {
      png = await captureBoundaryPng(key, pixelRatio: 2);
    });

    expect(png, isNotNull, reason: 'PNG harus terbentuk dari render offscreen');
    expect(png!.length, greaterThan(1000));
    // Magic number PNG: \x89 P N G
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('teks penutup dari pengaturan ikut tercetak di struk', (
    tester,
  ) async {
    await AppData.instance.saveReceiptFooter('Terima kasih, selamat datang!');
    expect(AppData.instance.receiptFooter, 'Terima kasih, selamat datang!');

    await _pump(
      tester,
      Scaffold(body: SingleChildScrollView(child: ReceiptDocument(order: _order()))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terima kasih, selamat datang!'), findsOneWidget);
    // Baris item struk berformat "qty x nama".
    expect(find.text('2x Dimsum Mentai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
