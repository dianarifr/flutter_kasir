/// Test pembatalan transaksi:
/// - order selesai hanya bisa dibatalkan admin dan wajib alasan,
/// - order diproses tetap bisa dibatalkan tanpa alasan,
/// - service mengirim alasan ke backend dan mem-parsing jejak batal.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/core/services/order_service.dart';
import 'package:flutter_kasir/features/orders/order_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outlet = Outlet(id: 2, name: 'Outlet Test');

const _admin = AuthUser(
  id: 10,
  name: 'Admin Test',
  username: 'admin',
  email: 'admin@test.local',
  role: 'admin',
  outlet: _outlet,
);

const _kasir = AuthUser(
  id: 11,
  name: 'Kasir Test',
  username: 'kasir',
  email: 'kasir@test.local',
  role: 'kasir',
  outlet: _outlet,
);

Order _order({
  bool isPaid = true,
  OrderStatus status = OrderStatus.selesai,
  String cancelReason = '',
}) => Order(
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
  isPaid: isPaid,
  status: status,
  paymentMethod: PaymentMethod.tunai,
  cashGiven: 50000,
  changeGiven: 20000,
  cancelReason: cancelReason,
);

Map<String, dynamic> _orderJson({
  String status = 'dibatalkan',
  String? cancelReason,
}) => {
  'id': 1,
  'code': 'INV001',
  'created_at': DateTime(2026, 11, 8).toIso8601String(),
  'queue_number': 12,
  'items': const [],
  'subtotal': 30000,
  'is_paid': true,
  'status': status,
  'payment_method': 'tunai',
  'cash_given': 50000,
  'change_amount': 20000,
  'cancel_reason': cancelReason,
  'cancelled_at': cancelReason == null ? null : '2026-11-08T10:00:00Z',
  'cancelled_by': cancelReason == null ? null : 'Admin Test',
};

http.Response _json(Object body, [int code = 200]) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});
    await AppData.instance.clearSessionLocal();
  });

  test('Order.fromJson membaca alasan & jejak pembatalan', () {
    final order = Order.fromJson(_orderJson(cancelReason: 'Salah input'));

    expect(order.status, OrderStatus.dibatalkan);
    // Pembayaran tetap tercatat walau transaksi dibatalkan.
    expect(order.isPaid, isTrue);
    expect(order.cancelReason, 'Salah input');
    expect(order.cancelledBy, 'Admin Test');
    expect(order.cancelledAt, isNotNull);
  });

  test('cancelOrder mengirim alasan yang sudah di-trim', () async {
    ApiClient.instance.setClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/orders/1/cancel'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['reason'], 'Salah input');
        return _json({
          'status': 'success',
          'data': _orderJson(cancelReason: 'Salah input'),
        });
      }),
    );

    final updated = await OrderService.instance.cancelOrder(
      1,
      reason: '  Salah input  ',
    );

    expect(updated.status, OrderStatus.dibatalkan);
    expect(updated.cancelReason, 'Salah input');
  });

  test('cancelOrder tanpa alasan tetap jalan untuk order diproses', () async {
    ApiClient.instance.setClient(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('reason'), isFalse);
        return _json({'status': 'success', 'data': _orderJson()});
      }),
    );

    final updated = await OrderService.instance.cancelOrder(1);
    expect(updated.status, OrderStatus.dibatalkan);
  });

  testWidgets('admin melihat aksi batal pada transaksi selesai', (
    tester,
  ) async {
    AppData.instance.setSession(_admin);
    ApiClient.instance.setClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/orders/1/cancel')) {
          return _json({
            'status': 'success',
            'data': _orderJson(cancelReason: 'Pelanggan batal'),
          });
        }
        if (path.endsWith('/shifts/current')) {
          return _json({'status': 'success', 'data': null});
        }
        if (path.endsWith('/products/stock') ||
            path.endsWith('/components/stock')) {
          return _json({'status': 'success', 'data': const []});
        }
        return _json({'status': 'error', 'message': 'Tidak dikenal'}, 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(orderId: '1', order: _order()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan Pesanan'), findsOneWidget);
    await tester.tap(find.text('Batalkan Pesanan'));
    await tester.pumpAndSettle();

    expect(find.text('Keterangan pembatalan'), findsOneWidget);

    // Tombol konfirmasi terkunci sampai alasan minimal 3 karakter.
    final confirm = find.widgetWithText(TextButton, 'Batalkan Pesanan');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Pelanggan batal');
    await tester.pump();
    expect(tester.widget<TextButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Pesanan Dibatalkan'), findsOneWidget);
    expect(find.text('Alasan batal: Pelanggan batal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kasir tidak melihat aksi batal pada transaksi selesai', (
    tester,
  ) async {
    AppData.instance.setSession(_kasir);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(orderId: '1', order: _order()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Batalkan Pesanan'), findsNothing);
  });

  testWidgets('order yang masih diproses tampil tanpa alasan di detail', (
    tester,
  ) async {
    // Aksi batal order pending ada di menu Daftar Pesanan (alur lama),
    // bukan di halaman detail. Halaman detail tidak menampilkan aksi
    // batal untuk order yang belum selesai.
    AppData.instance.setSession(_admin);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(
          orderId: '1',
          order: _order(isPaid: false, status: OrderStatus.diproses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}
