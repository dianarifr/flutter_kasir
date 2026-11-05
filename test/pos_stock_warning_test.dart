/// Regresi penyederhanaan warning stok:
///
/// - Katalog POS: tombol "Tambah" / "+" TIDAK boleh memunculkan dialog
///   peringatan stok (dulu dialog "Stok Bahan Kurang").
/// - Checkout: kartu peringatan bahan kurang TETAP tampil, dan muncul
///   walau stok berdetail belum dimuat siapa pun sebelum halaman ini
///   dibuka (halaman checkout memuatnya sendiri).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/data/app_data.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/features/pos/pos_catalog_page.dart';
import 'package:flutter_kasir/features/pos/pos_checkout_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _authUser = AuthUser(
  id: 1,
  name: 'Kasir',
  username: 'kasir',
  email: 'kasir@kasir.com',
  role: 'kasir',
  outlet: Outlet(id: 7, name: 'Outlet Pusat'),
);

/// Stok produk: satu bahan (Beras) sudah habis.
const _productJson = {
  'id': 10,
  'name': 'Nasi Goreng',
  'price': 25000,
  'image_url': null,
};

const _stockJson = {
  'id': 10,
  'name': 'Nasi Goreng',
  'price': 25000,
  'stock': 0,
  'is_stock_tracked': true,
  'components': [
    {
      'component_id': 3,
      'component_name': 'Beras',
      'qty_per_portion': 1,
      'current_stock': 0,
      'max_portions': 0,
    },
  ],
};

http.Response _json(Object payload) => http.Response(
  jsonEncode(payload),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setToken('token-uji');
    ApiClient.instance.setClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/products')) {
          return _json({
            'status': 'success',
            'data': [_productJson],
          });
        }
        if (path.endsWith('/products/stock')) {
          return _json({
            'status': 'success',
            'data': [_stockJson],
          });
        }
        if (path.endsWith('/charges') || path.endsWith('/orders/customers')) {
          return _json({'status': 'success', 'data': []});
        }
        return _json({'status': 'error', 'message': 'endpoint tak terduga'});
      }),
    );
    AppData.instance.setSession(_authUser);
  });

  testWidgets('Tambah produk di katalog tidak memunculkan dialog stok', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PosCatalogPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Dialog lama tidak boleh muncul lagi.
    expect(find.text('Stok Bahan Kurang'), findsNothing);

    // Produk tetap masuk keranjang: tombol berganti jadi pemilih jumlah.
    expect(AppData.instance.cartQty('10'), 1);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
    'Kartu peringatan bahan kurang tetap tampil di checkout '
    'walau stok belum dimuat sebelumnya',
    (tester) async {
      // Produk dimuat, tapi stok berdetail sengaja TIDAK dimuat dulu —
      // meniru user yang langsung checkout tanpa membuka katalog.
      await AppData.instance.loadProducts();
      AppData.instance.addToCart('10');
      expect(AppData.instance.productStocks, isEmpty);

      await tester.pumpWidget(const MaterialApp(home: PosCheckoutPage()));
      await tester.pumpAndSettle();

      // Halaman checkout memuat stoknya sendiri, jadi kartu tetap muncul.
      expect(AppData.instance.productStocks, isNotEmpty);
      expect(find.text('Bahan kurang/habis'), findsOneWidget);
      expect(find.textContaining('Beras'), findsOneWidget);
    },
  );
}
