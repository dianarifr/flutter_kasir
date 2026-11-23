/// Test pengaturan struk: teks penutup dari backend + cache lokal, dan
/// caption otomatis saat struk dibagikan sebagai gambar.
library;

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_kasir/core/network/api_client.dart';
import 'package:flutter_kasir/core/services/receipt_settings_service.dart';
import 'package:flutter_kasir/features/receipt/receipt_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outletId = 7;

/// Backend palsu: menyimpan `receipt_footer` satu outlet.
class _FakeBackend {
  _FakeBackend();

  String? receiptFooter;
  bool offline = false;
  int putCount = 0;

  MockClient get client => MockClient((request) async {
    if (offline) {
      throw const SocketExceptionStub();
    }

    if (request.method == 'GET' && request.url.path.endsWith('/receipt-settings')) {
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {'receipt_footer': receiptFooter},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.method == 'PUT' && request.url.path.endsWith('/receipt-settings')) {
      putCount++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final raw = (body['receipt_footer'] as String? ?? '').trim();
      receiptFooter = raw.isEmpty ? null : raw;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {'receipt_footer': receiptFooter},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response(
      jsonEncode({'status': 'error', 'message': 'Tidak dikenal'}),
      404,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Kegagalan jaringan sederhana (tanpa import dart:io agar tetap aman di web).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'jaringan mati';
}

void main() {
  late _FakeBackend backend;

  setUp(() {
    // Test tidak memuat asset .env; isi manual agar ApiConfig punya URL.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://test.local/api\n');
    SharedPreferences.setMockInitialValues({});
    backend = _FakeBackend();
    ApiClient.instance.setClient(backend.client);
  });

  group('ReceiptSettingsService', () {
    test('backend kosong: memakai teks bawaan', () async {
      expect(
        await ReceiptSettingsService.instance.fetchFooter(_outletId),
        kDefaultReceiptFooter,
      );
    });

    test('teks dari backend dipakai dan disimpan sebagai cache', () async {
      backend.receiptFooter = 'Terima kasih, sampai jumpa!';

      expect(
        await ReceiptSettingsService.instance.fetchFooter(_outletId),
        'Terima kasih, sampai jumpa!',
      );

      // Cache terisi: saat offline pun teks yang sama tetap tampil.
      backend.offline = true;
      expect(
        await ReceiptSettingsService.instance.fetchFooter(_outletId),
        'Terima kasih, sampai jumpa!',
      );
    });

    test('simpan mengirim teks ter-trim ke backend dan memperbarui cache',
        () async {
      await ReceiptSettingsService.instance.saveFooter(
        _outletId,
        '  Sudah dicoba  ',
      );

      expect(backend.putCount, 1);
      expect(backend.receiptFooter, 'Sudah dicoba');
      expect(
        await ReceiptSettingsService.instance.fetchFooter(_outletId),
        'Sudah dicoba',
      );
    });

    test('teks kosong dikirim kosong, backend menyimpannya null', () async {
      backend.receiptFooter = 'Teks lama';

      await ReceiptSettingsService.instance.saveFooter(_outletId, '   ');

      expect(backend.receiptFooter, isNull);
      // Di app, null berarti kembali ke teks bawaan.
      expect(
        await ReceiptSettingsService.instance.fetchFooter(_outletId),
        kDefaultReceiptFooter,
      );
    });

    test('simpan saat offline melempar error (perubahan tidak tersimpan)',
        () async {
      backend.offline = true;

      expect(
        () => ReceiptSettingsService.instance.saveFooter(_outletId, 'Baru'),
        throwsA(isA<Exception>()),
      );
    });

    test('teks lokal lama diunggah sekali saat backend masih kosong',
        () async {
      SharedPreferences.setMockInitialValues({
        'receipt_footer_outlet_$_outletId': 'Teks dari versi lama',
      });

      final uploaded = await ReceiptSettingsService.instance
          .uploadLocalFooterIfMissing(_outletId);

      expect(uploaded, isTrue);
      expect(backend.receiptFooter, 'Teks dari versi lama');
    });

    test('teks lokal tidak menimpa backend yang sudah terisi', () async {
      SharedPreferences.setMockInitialValues({
        'receipt_footer_outlet_$_outletId': 'Teks dari versi lama',
      });
      backend.receiptFooter = 'Sudah ada di server';

      final uploaded = await ReceiptSettingsService.instance
          .uploadLocalFooterIfMissing(_outletId);

      expect(uploaded, isFalse);
      expect(backend.receiptFooter, 'Sudah ada di server');
      expect(backend.putCount, 0);
    });

    test('akun tanpa outlet tidak memanggil API', () async {
      await ReceiptSettingsService.instance.saveFooter(null, 'Lokal saja');

      expect(backend.putCount, 0);
      expect(
        await ReceiptSettingsService.instance.fetchFooter(null),
        'Lokal saja',
      );
    });
  });

  group('normalizeFooter', () {
    test('kosong/spasi menjadi default', () {
      expect(ReceiptSettingsService.normalizeFooter(''), kDefaultReceiptFooter);
      expect(
        ReceiptSettingsService.normalizeFooter('\n  '),
        kDefaultReceiptFooter,
      );
    });
  });

  group('buildReceiptCaption', () {
    test('menyertakan nama outlet', () {
      expect(
        buildReceiptCaption('Cabang Pusat'),
        'Halo! Nyemil Nyam Cabang Pusat mengirimkan struk untuk kamu',
      );
    });

    test('outlet kosong/sama dengan brand tidak dobel', () {
      const expected = 'Halo! Nyemil Nyam mengirimkan struk untuk kamu';
      expect(buildReceiptCaption(''), expected);
      expect(buildReceiptCaption('  '), expected);
      expect(buildReceiptCaption('nyemil nyam'), expected);
    });
  });
}