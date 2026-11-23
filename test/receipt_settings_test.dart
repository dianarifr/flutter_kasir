/// Test pengaturan struk: teks penutup default/per outlet dan caption
/// otomatis saat struk dibagikan sebagai gambar.
library;

import 'package:flutter_kasir/core/services/receipt_settings_service.dart';
import 'package:flutter_kasir/features/receipt/receipt_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReceiptSettingsService', () {
    test('belum pernah disimpan: memakai teks bawaan', () async {
      expect(
        await ReceiptSettingsService.instance.fetchFooter(1),
        kDefaultReceiptFooter,
      );
    });

    test('teks tersimpan per outlet dan tidak bocor antar outlet', () async {
      await ReceiptSettingsService.instance.saveFooter(1, 'Outlet satu');
      await ReceiptSettingsService.instance.saveFooter(2, 'Outlet dua\nBaris 2');

      expect(
        await ReceiptSettingsService.instance.fetchFooter(1),
        'Outlet satu',
      );
      expect(
        await ReceiptSettingsService.instance.fetchFooter(2),
        'Outlet dua\nBaris 2',
      );
      expect(
        await ReceiptSettingsService.instance.fetchFooter(3),
        kDefaultReceiptFooter,
      );
    });

    test('teks kosong/spasi disimpan sebagai default', () async {
      await ReceiptSettingsService.instance.saveFooter(1, '   ');

      expect(
        await ReceiptSettingsService.instance.fetchFooter(1),
        kDefaultReceiptFooter,
      );
      expect(ReceiptSettingsService.normalizeFooter('\n  '), kDefaultReceiptFooter);
    });

    test('akun tanpa outlet memakai key global', () async {
      await ReceiptSettingsService.instance.saveFooter(null, 'Tanpa outlet');

      expect(
        await ReceiptSettingsService.instance.fetchFooter(null),
        'Tanpa outlet',
      );
      expect(
        await ReceiptSettingsService.instance.fetchFooter(1),
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