/// Regresi startup: membuka app dengan akun tersimpan tidak boleh
/// memicu assertion `'!_dirty': is not true`.
///
/// Penyebab lamanya: `MainShell.initState` memuat shift (yang langsung
/// `notifyListeners()`) saat `MainShell` masih dibangun di dalam
/// `ListenableBuilder` milik `home`.
library;

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/data/models.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/core/services/account_store.dart';
import 'package:flutter_kasir/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  testWidgets('startup dengan akun tersimpan tidak melempar assertion', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});

    // Sesi tersimpan: user + outlet aktif.
    final now = DateTime.now().millisecondsSinceEpoch;
    const user = AuthUser(
      id: 1,
      name: 'Kasir Medayu',
      username: 'medayu',
      email: 'medayu@kasir.com',
      role: 'kasir',
      outlet: Outlet(id: 2, name: 'Medayu'),
    );
    await AccountStore.instance.upsert(
      SavedAccount(
        userId: user.id,
        token: 'token-aktif',
        user: user,
        addedAt: now,
        lastUsedAt: now,
      ),
    );
    await AccountStore.instance.setActive(user.id);

    ApiClient.instance.setClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/user-info')) {
          return _json({
            'id': 1,
            'name': 'Kasir Medayu',
            'username': 'medayu',
            'email': 'medayu@kasir.com',
            'role': 'kasir',
            'outlet': {'id': 2, 'name': 'Medayu', 'address': ''},
          });
        }
        if (path.endsWith('/shifts/current')) {
          return _json({'data': null});
        }
        // Endpoint dashboard lain (orders, stok bahan, dll).
        return _json({'data': []});
      }),
    );

    await tester.pumpWidget(const PosApp());
    // Beri waktu restoreSession + build MainShell + post-frame loaders.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsWidgets);
  });
}