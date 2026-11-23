/// Test filter tanggal di Daftar Pesanan.
///
/// Yang dijaga:
/// - setiap permintaan order membawa parameter `date` (YYYY-MM-DD),
/// - pilihan tanggal kasir bertahan walau Dashboard memuat data hari ini,
/// - kartu tanggal lama langsung dibuang saat tanggal berganti,
/// - angka Dashboard (`paidOrders`/`todayRevenue`) tetap hanya hari ini.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/core/theme/app_theme.dart';
import 'package:flutter_kasir/core/utils/formatters.dart';
import 'package:flutter_kasir/features/orders/order_list_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _outletId = 3;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Format tanggal sama dengan yang dikirim [OrderService] (lokal).
String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _orderJson({
  required int id,
  required DateTime createdAt,
  bool isPaid = true,
  int subtotal = 25000,
}) => {
  'id': id,
  'code': 'ORD-$id',
  'customer_name': 'Pelanggan $id',
  'created_at': createdAt.toIso8601String(),
  'queue_number': id,
  'items': const [],
  'subtotal': subtotal,
  'is_paid': isPaid,
  'status': 'selesai',
  'payment_method': 'tunai',
};

/// Backend palsu: menyajikan order per tanggal dan mencatat query `date`.
class _FakeOrdersBackend {
  final Map<String, List<Map<String, dynamic>>> byDate = {};
  final List<String?> requestedDates = [];
  Duration delay = Duration.zero;

  MockClient get client => MockClient((request) async {
    if (!request.url.path.endsWith('/orders')) {
      return http.Response(
        jsonEncode({'status': 'error', 'message': 'Tidak dikenal'}),
        404,
        headers: {'content-type': 'application/json'},
      );
    }

    final date = request.url.queryParameters['date'];
    requestedDates.add(date);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    return http.Response(
      jsonEncode({
        'status': 'success',
        'data': byDate[date] ?? const <Map<String, dynamic>>[],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  late _FakeOrdersBackend backend;
  final today = _dateOnly(DateTime.now());
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  final data = AppData.instance;

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    backend = _FakeOrdersBackend();
    ApiClient.instance.setClient(backend.client);
    ApiClient.instance.setToken('token-test');

    // Sesi baru sekaligus mereset daftar order & tanggal pilihan.
    data.setSession(
      const AuthUser(
        id: 1,
        name: 'Kasir Test',
        username: 'kasir',
        email: 'kasir@test.local',
        role: 'kasir',
        outlet: Outlet(id: _outletId, name: 'Outlet Test'),
      ),
    );

    backend.byDate[_dateKey(today)] = [
      _orderJson(
        id: 1,
        createdAt: DateTime(today.year, today.month, today.day, 9),
      ),
    ];
    backend.byDate[_dateKey(yesterday)] = [
      _orderJson(
        id: 2,
        createdAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 10),
      ),
    ];
  });

  test(
    'loadOrders() mengirim tanggal hari ini dan memuat order hari ini',
    () async {
      await data.loadOrders();

      expect(backend.requestedDates.single, _dateKey(today));
      expect(data.ordersDate, today);
      expect(data.orderListDate, today);
      expect(data.orders.map((o) => o.id), ['1']);
    },
  );

  test('loadOrdersForDate() memakai tanggal pilihan kasir', () async {
    await data.loadOrdersForDate(yesterday);

    expect(backend.requestedDates.single, _dateKey(yesterday));
    expect(data.ordersDate, yesterday);
    expect(data.orderListDate, yesterday);
    expect(data.orders.map((o) => o.id), ['2']);
  });

  test(
    'muat data Dashboard (hari ini) tidak menghapus pilihan tanggal kasir',
    () async {
      await data.loadOrdersForDate(yesterday);
      await data.loadOrders(date: DateTime.now());

      expect(data.ordersDate, today);
      expect(data.orderListDate, yesterday);
      expect(data.orders.map((o) => o.id), ['1']);
    },
  );

  test('kartu tanggal lama dibuang begitu tanggal berganti', () async {
    backend.delay = const Duration(milliseconds: 20);

    final future = data.loadOrdersForDate(yesterday);
    // Sebelum respons datang, daftar lama tidak boleh tampil di bawah label
    // tanggal yang baru.
    expect(data.orders, isEmpty);

    await future;
    expect(data.orders.map((o) => o.id), ['2']);
  });

  test('paidOrders & todayRevenue hanya menghitung order hari ini', () async {
    await data.loadOrdersForDate(yesterday);

    expect(data.orders, isNotEmpty);
    expect(data.paidOrders, isEmpty);
    expect(data.todayRevenue, 0);
    expect(data.recentOrders, isEmpty);

    await data.loadOrdersForDate(today);
    expect(data.paidOrders.map((o) => o.id), ['1']);
    expect(data.todayRevenue, 25000);
  });

  test('kembali ke hari ini memperbarui pilihan tanggal', () async {
    await data.loadOrdersForDate(yesterday);
    expect(data.orderListDate, yesterday);

    await data.loadOrdersForDate(DateTime.now());
    expect(data.orderListDate, today);
    expect(data.ordersDate, today);
    expect(data.orders.map((o) => o.id), ['1']);
  });

  testWidgets('UI menampilkan tanggal pilihan & tombol kembali ke hari ini', (
    tester,
  ) async {
    await data.loadOrdersForDate(yesterday);

    await tester.pumpWidget(
      MaterialApp(theme: buildLightTheme(), home: const OrderListPage()),
    );
    await tester.pumpAndSettle();

    // Tanggal lampau: label tanpa "Hari ini", tombol pintas muncul, dan
    // hanya order tanggal itu yang tampil.
    expect(find.text(formatDateShort(yesterday)), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('No. Pesanan: ORD-2'), findsWidgets);
    expect(find.text('No. Pesanan: ORD-1'), findsNothing);

    await tester.tap(find.text('Hari ini'));
    await tester.pumpAndSettle();

    expect(find.text('Hari ini, ${formatDateShort(today)}'), findsOneWidget);
    expect(find.text('Hari ini'), findsNothing);
    expect(find.text('No. Pesanan: ORD-1'), findsWidgets);
    expect(find.text('No. Pesanan: ORD-2'), findsNothing);
  });
}
