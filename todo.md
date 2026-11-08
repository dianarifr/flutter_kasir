# Todo: Print Struk Bluetooth (Printer EPPOS)

Tanggal rencana: 5 Nov 2026. Hanya repo app (`flutter_kasir`); **backend tidak
diubah**.

---

## Ringkasan keputusan

| Topik | Keputusan |
|---|---|
| Printer | EPPOS 58mm, ESC/POS, Bluetooth Classic (SPP) |
| Pairing | Pair dulu di Pengaturan Bluetooth Android (PIN `0000`/`1234`); app hanya menampilkan perangkat yang sudah ter-pair |
| Package | `print_bluetooth_thermal ^1.2.5` + `esc_pos_utils_plus ^2.0.4` |
| Penyimpanan | MAC printer, nama printer, ukuran kertas, toggle auto-print di `SharedPreferences` |
| Ukuran kertas | Default 58mm, opsi 80mm (perlu konfirmasi) |
| Auto print | Default mati, bisa dinyalakan di pengaturan (perlu konfirmasi) |
| Entri pengaturan | Drawer "Printer Bluetooth" |
| Isi struk | Sama dengan struk di layar; alamat outlet + nama kasir opsional (perlu konfirmasi) |

Catatan: resolusi dependency sudah dicek lewat `flutter pub add --dry-run` di
project ini (Flutter 3.47.6 / Dart 3.13.5) dan berhasil.

---

## 1. Dependency & konfigurasi platform

- [ ] `pubspec.yaml`: tambah `print_bluetooth_thermal: ^1.2.5` dan
      `esc_pos_utils_plus: ^2.0.4`.
- [ ] `android/app/src/main/AndroidManifest.xml`: tambah
      `BLUETOOTH_CONNECT`, `BLUETOOTH` + `BLUETOOTH_ADMIN` dengan
      `maxSdkVersion="30"`, dan
      `<uses-feature android:name="android.hardware.bluetooth" android:required="false"/>`.
      Izin runtime Android 12+ sudah diminta oleh plugin lewat
      `isPermissionBluetoothGranted`.
- [ ] `ios/Runner/Info.plist`: tambah `NSBluetoothAlwaysUsageDescription` dan
      `NSBluetoothPeripheralUsageDescription` (untuk build iOS nanti).
- [ ] Jalankan `flutter pub get`.

## 2. `lib/core/services/printer_service.dart` (baru)

Singleton `ChangeNotifier` + abstraksi transport agar bisa dites tanpa
Bluetooth asli:

```dart
class PrinterDevice {
  final String name;
  final String mac;
}

abstract class PrinterTransport {
  Future<bool> isBluetoothEnabled();
  Future<bool> ensurePermission();          // request izin Android 12+
  Future<List<PrinterDevice>> pairedDevices();
  Future<bool> connect(String mac);
  Future<bool> isConnected();
  Future<bool> write(List<int> bytes);
  Future<void> disconnect();
}
```

Implementasi default `BluetoothPrinterTransport` membungkus
`PrintBluetoothThermal`.

API `PrinterService`:

```dart
Future<void> ensureLoaded();
Future<List<PrinterDevice>> discover();
Future<void> saveDevice(PrinterDevice device);
Future<void> forget();
Future<void> setPaperMm(int mm);
Future<void> setAutoPrint(bool value);
Future<void> connect();
Future<void> disconnect();
Future<void> printOrder(Order order, {String outletName, String outletAddress});
Future<void> printTest();
```

- [ ] Key `SharedPreferences`: `printer_mac`, `printer_name`, `printer_paper_mm`
      (default 58), `printer_auto_print` (default `false`).
- [ ] `printOrder()`: kalau belum tersambung -> auto-connect MAC tersimpan.
- [ ] Kalau `write` gagal -> disconnect, connect ulang, kirim sekali lagi
      (retry satu kali).
- [ ] Serialisasi print dengan flag `_isPrinting` supaya dua struk tidak
      bertabrakan.
- [ ] Pesan error ramah: Bluetooth mati, izin ditolak, printer belum diatur,
      printer tidak ditemukan, gagal mengirim data.
- [ ] `printTest()` memakai struk contoh 1 item.

## 3. `lib/core/services/receipt_escpos.dart` (baru)

Builder struk murni (tanpa akses platform) supaya mudah diuji.

- [ ] `Future<List<int>> build(Order order, {required String outletName,
      String outletAddress, required int paperMm})`.
- [ ] Layout 58mm = 32 karakter, 80mm = 48 karakter.
- [ ] Header: nama toko (bold, double size, center), nama + alamat outlet.
- [ ] Info: No. Struk, Tanggal, Pelanggan, Antrian.
- [ ] Item: `qty x nama` + subtotal rata kanan; teks panjang di-wrap; catatan
      item ikut dicetak.
- [ ] Biaya: Subtotal, charge dinamis (persen/nominal) atau fallback
      Diskon/Biaya Tambahan, lalu TOTAL (bold).
- [ ] Status: `LUNAS` / `BELUM DIBAYAR` / `DIBATALKAN`.
- [ ] Pembayaran: Metode; Tunai diterima + Kembalian; atau Tunai + Non Tunai
      untuk pembayaran campuran.
- [ ] Footer "Terima kasih telah berbelanja", `feed(3)`, `cut()`.
- [ ] Pakai `CapabilityProfile.load()` + `Generator(PaperSize.mm58/mm80,
      profile)`; code table `CP1252` agar karakter non-ASCII aman.

## 4. `lib/features/settings/printer_settings_page.dart` (baru)

- [ ] Kartu status: tersambung/terputus + nama & MAC printer.
- [ ] Tombol "Pilih Printer" -> bottom sheet daftar perangkat ter-pair
      (nama + MAC), tap untuk simpan + connect.
- [ ] Tombol "Hubungkan" / "Putuskan".
- [ ] Pilihan ukuran kertas 58mm / 80mm.
- [ ] Switch "Cetak otomatis setelah pembayaran".
- [ ] Tombol "Cetak Tes".
- [ ] Tombol "Lupakan printer".
- [ ] Kartu panduan pairing: nyalakan printer -> Pengaturan Bluetooth ->
      pair (`0000`/`1234`) -> kembali ke app.
- [ ] Empty state kalau belum ada perangkat ter-pair + tombol refresh.
- [ ] Semua error ditampilkan lewat `SnackBar` (bukan dialog generik).

## 5. Integrasi UI

- [ ] `lib/features/receipt/receipt_page.dart`: jadikan `StatefulWidget`.
  - [ ] Ganti snackbar demo "Struk dikirim ke printer (demo)" dengan print
        sungguhan + loading state.
  - [ ] Kalau printer belum diatur -> dialog dengan tombol "Atur Printer".
  - [ ] SnackBar sukses "Struk berhasil dicetak"; gagal -> pesan + aksi
        "Pengaturan".
  - [ ] Icon printer di AppBar untuk membuka pengaturan.
  - [ ] Kirim `outletName` + `outletAddress` dari `AppData.currentOutlet`.
- [ ] `lib/features/dashboard/main_shell.dart`: tambah menu drawer
      "Printer Bluetooth" yang push ke `PrinterSettingsPage`.
- [ ] `lib/features/pos/pos_payment_page.dart`: dukung auto-print setelah
      pembayaran (kalau toggle aktif), tanpa menghalangi navigasi ke struk.
- [ ] Cetak ulang dari `order_list_page.dart` otomatis ikut berfungsi karena
      memakai `ReceiptPage` yang sama.

## 6. Test

| File | Isi |
|---|---|
| `test/printer_receipt_test.dart` (baru) | isi struk, format Rupiah, wrap 58 vs 80mm, status pesanan, diskon/charge |
| `test/printer_service_test.dart` (baru) | simpan/pilih printer, retry sekali saat gagal, error kalau belum diatur, auto-print setting |

- [ ] `flutter analyze` bersih.
- [ ] `flutter test` semua lolos.

## 7. Verifikasi manual (dengan printer EPPOS)

1. [ ] Pair printer di Pengaturan Bluetooth Android.
2. [ ] Buka app -> drawer -> Printer Bluetooth -> Pilih Printer -> Hubungkan.
3. [ ] Cetak Tes: teks, bold, rata kanan, dan potong kertas benar.
4. [ ] Bayar order tunai -> Cetak Struk: nominal, kembalian, total sesuai.
5. [ ] Cetak order non-tunai dan campuran.
6. [ ] Cetak struk dari Daftar Pesanan (termasuk yang belum dibayar).
7. [ ] Matikan printer saat cetak -> muncul pesan error yang jelas, app tidak
       crash.
8. [ ] `./scripts/build-apk.sh` berhasil (memastikan plugin Bluetooth lolos
       build release AGP 9).

## 8. Risiko & catatan

1. **Build AGP 9 / Gradle 9.3**: `print_bluetooth_thermal` 1.2.5 sudah
   mendukung AGP 9, dan Flutter otomatis meng-apply KGP karena project memakai
   `android.builtInKotlin=false`. Kalau build tetap gagal, fallback: buat bridge
   Bluetooth SPP sendiri di `MainActivity.kt` (MethodChannel, ±120 baris) tanpa
   plugin native.
2. **`writeBytes` plugin berjalan di main thread** — struk kecil (±5-10 KB)
   aman, tapi tetap beri loading state di UI.
3. **`connectionStatus` plugin menulis satu spasi ke printer** — jangan dipanggil
   berulang tanpa perlu.
4. **Printer murah bisa kehilangan data** kalau dikirim terlalu cepat; plugin
   sudah menulis per chunk 16 KB + flush.
5. **Hanya perangkat ter-pair** yang tampil; scan perangkat baru dari dalam app
   belum termasuk (butuh izin tambahan).
6. **iOS/desktop belum diuji** — target utama Android.

## 9. Perlu dikonfirmasi user

1. Ukuran kertas: **58mm** atau **80mm**? (rencana: default 58mm + opsi 80mm)
2. Cetak otomatis setelah pembayaran: default **mati** + toggle, atau langsung
   otomatis?
3. Isi struk: sama persis dengan layar, atau tambah **alamat outlet + nama
   kasir**?
4. Menu pengaturan printer: **drawer** (rencana) atau icon di AppBar saja?

## 10. Estimasi

±3-4 jam termasuk test, build APK, dan QA dengan printer fisik.