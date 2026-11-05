# Todo: Multi-Device, Multi-Akun (ala Instagram), dan Penyederhanaan Warning Stok

Repo app: `/var/www/html/php8/flutter_kasir`
Repo backend: `/var/www/html/php8/kasir-app`

---

## Ringkasan keputusan

| Topik | Keputusan |
|---|---|
| Satu akun di banyak device | **Diizinkan** (token per device, tidak saling menghapus) |
| Quick switch akun | **Token saja**, tanpa menyimpan password |
| Lokasi UI ganti akun | **AppBar kanan atas** (nama akun) -> bottom sheet |
| Drawer | **Tidak diubah** |
| Maks akun tersimpan | **5 akun** |
| Warning stok saat Tambah di katalog | **Dihapus** |
| Warning stok di halaman checkout | **Tetap** |
| Warning stok setelah Bayar Langsung / Simpan Pesanan | **Dihapus keduanya** |

---

## Bagian 1 - Backend `kasir-app`

### 1.1 `app/Http/Controllers/Api/AuthController.php`

Masalah sekarang (baris 44-48):

```php
// Hapus token lama biar gak numpuk (optional)
$user->tokens()->delete();
$token = $user->createToken($request->device_name)->plainTextToken;
```

`tokens()->delete()` menghapus **semua** token milik user. Device A langsung 401
begitu device B login. Inilah penyebab "salah satu device ke-logout".

Perbaikan:

```php
// Validator: tambah device_id
'device_id' => 'nullable|string|max:100',

// Ganti penghapusan global jadi per-device
$deviceKey = $request->device_id ?: $request->device_name;
$user->tokens()->where('name', $deviceKey)->delete();
$token = $user->createToken($deviceKey)->plainTextToken;
```

Efek:
- Device A dan B bisa aktif bersamaan.
- Re-login di device yang sama mengganti token device itu saja (tidak menumpuk).
- `device_name` tetap dipakai sebagai fallback bila app lama belum mengirim `device_id`.

### 1.2 `routes/api.php` - `/user-info` harus menyertakan outlet

Sekarang:

```php
Route::get('/user-info', function (Request $request) {
    return $request->user();
});
```

Tanpa `outlet`, validasi token saat ganti akun akan mengembalikan user dengan
`outlet = null` -> app menampilkan "Tanpa Outlet" dan gerbang shift terlewat.

```php
Route::get('/user-info', fn (Request $request) => $request->user()->load('outlet'));
```

### 1.3 Opsional - `POST /logout-all`

```php
Route::post('/logout-all', function (Request $request) {
    $request->user()->tokens()->delete();
    return response()->json(['message' => 'Logout dari semua perangkat berhasil.']);
});
```

Dipakai tombol "Keluar dari semua akun" di app.

### 1.4 Wajib punya outlet (tambahan 5 Nov 2026) - [x] SELESAI

Login ditolak `403` dengan pesan "Akun ini belum terhubung ke outlet.
Hubungi admin." bila `outlet_id` user kosong. Alasannya: harga, stok, dan
shift semuanya terikat outlet, sehingga app POS tidak berguna tanpa outlet.
Test baru: `login_ditolak_jika_user_tidak_terhubung_ke_outlet`.

### 1.5 Masa berlaku token (tambahan 5 Nov 2026) - [x] SELESAI

`config/sanctum.php` sekarang memakai `SANCTUM_EXPIRATION` (menit) dengan
default 30 hari. Token lama otomatis ditolak Guard setelah melewati batas.
Test baru: `token_kedaluwarsa_setelah_masa_berlaku`.

### 1.6 Pembersihan token legacy (tambahan 5 Nov 2026) - [x] SELESAI

Perintah baru: `php artisan tokens:prune-legacy [--dry-run] [--force]`.
Menghapus token yang namanya bukan `dev-*` (token lama yang dibuat sebelum
app mengirim `device_id`). Di production, perintah minta konfirmasi kecuali
`--force`.

### Uji backend
1. Login user yang sama dari 2 device / 2 emulator.
2. Pastikan keduanya bisa memanggil `GET /orders` bersamaan (tidak 401).
3. Login ulang di device A -> token A lama mati, token B tetap hidup.

---

## Bagian 2 - Flutter: fondasi data

### 2.1 `lib/core/data/models.dart`
Tambah `toJson()` untuk `Outlet` dan `AuthUser` (belum ada; `toJson()` di
baris 73 milik `Product`).

```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'address': address,
}; // Outlet

Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'username': username,
  'email': email,
  'role': role,
  'outlet': outlet?.toJson(),
}; // AuthUser
```

### 2.2 File baru `lib/core/services/account_store.dart`

Menggantikan peran `TokenStorage` untuk data sesi.

Key di `SharedPreferences`:

| Key | Isi |
|---|---|
| `saved_accounts` | JSON list, maks 5 entri |
| `active_account_id` | `int?` userId yang aktif |
| `device_id` | uuid stabil, dibuat sekali |

Bentuk entri:

```json
{
  "userId": 12,
  "token": "1|abc...",
  "user": { "id": 12, "name": "...", "username": "...", "outlet": {...} },
  "addedAt": 1730000000000,
  "lastUsedAt": 1730000000000
}
```

API:

```dart
Future<List<SavedAccount>> readAccounts();
Future<SavedAccount?> readActive();
Future<void> upsert(SavedAccount account);   // dedupe by userId, terbaru di atas
Future<void> remove(int userId);
Future<void> setActive(int? userId);
Future<void> clearAll();
Future<String> deviceId();                    // buat + simpan bila belum ada
Future<void> migrateLegacy();                 // sekali, dipanggil di main()
```

`upsert()`: buang entri dengan `userId` sama, sisip di posisi 0, kalau panjang
> 5 buang entri dengan `lastUsedAt` paling lama.

`migrateLegacy()`: bila `auth_token` + `auth_user` lama masih ada -> jadikan
entri pertama -> hapus key lama. User yang sudah login **tidak** ter-logout
setelah update.

### 2.3 `lib/core/services/token_storage.dart`
- **Hapus** penyimpanan password (`_rememberedPasswordKey`, `saveCredentials`,
  `readCredentials`).
- Sisakan `remembered_username` + `remember_me` untuk prefill username di form
  login.
- Key `auth_token` / `auth_user` menjadi legacy - dibaca sekali oleh
  `migrateLegacy()`, lalu dihapus.

Alasan: dengan sampai 5 akun, menyimpan 5 password plaintext di
SharedPreferences terlalu berisiko.

### 2.4 `pubspec.yaml` (opsional) - [x] diputuskan tanpa dependency baru
`device_id` memakai timestamp + random (`dev-...`). `device_name` yang
dikirim ke server memakai `"Nyemil Nyam"` sebagai default. `device_info_plus`
tidak ditambahkan.

---

## Bagian 3 - Flutter: layanan sesi

### 3.1 `lib/core/services/auth_service.dart`

| Method | Perilaku baru |
|---|---|
| `login()` | kirim `device_name` + `device_id`; `AccountStore.upsert()`; `setActive`; `setToken()` |
| `switchAccount(int userId)` | ambil token akun -> `setToken` -> `GET /user-info`. Sukses: perbarui data user tersimpan. 401: hapus akun itu, kembalikan error. Gagal jaringan: lanjut pakai data cache (mode offline) |
| `logout()` | `POST /logout` (revoke token aktif saja) -> hapus akun aktif dari store -> **auto-switch ke akun lain** bila ada -> kalau kosong, ke halaman login |
| `logoutAll()` | revoke token aktif + `AccountStore.clearAll()` |
| `restoreSession()` | `migrateLegacy()` -> baca akun aktif -> `setToken` -> validasi `/user-info` di latar |
| `handleUnauthorized()` | hapus **hanya** akun aktif; kalau ada akun lain -> switch diam-diam (`true`), kalau kosong -> `false` |

Perilaku `remember = false`: jangan simpan ke daftar akun; token hanya di memori
(seperti sekarang).

### 3.2 `lib/core/network/api_client.dart`

`onUnauthorized` menjadi `Future<bool> Function()?`:

```dart
// true  = sudah ditangani (pindah ke akun lain), jangan ke login
// false = tidak ada akun lain, app harus ke halaman login
final handled = await onUnauthorized?.call() ?? false;
```

Kunci pengunci `_isNotifyingUnauthorized` tetap dipakai agar banyak 401 paralel
hanya memicu satu penanganan.

### 3.3 `lib/core/data/app_data.dart`

- `clearSessionLocal()` **jangan** hapus cache `products_outlet_$id` /
  `charges_outlet_$id` selama masih ada akun tersimpan dengan outlet yang sama.
  Cache memang di-key per outlet sehingga aman dipakai bersama. Hapus hanya saat
  `logoutAll`.
- Tambah `switchAccount(AuthUser user, String token)` -> `setSession(user)`
  (sudah membersihkan cart, order, shift, riwayat) tanpa menyentuh cache.
- `setSession()` sudah cukup untuk reset state; tidak perlu perubahan lain.

### 3.4 `lib/main.dart`

- `home:` dibungkus `ListenableBuilder(listenable: AppData.instance)` supaya
  ganti akun langsung mengganti layar tanpa navigasi manual.
- `restoreSession()` dipanggil setelah `AccountStore.migrateLegacy()`.
- `onUnauthorized` diarahkan ke `AuthService.handleUnauthorized()`; bila `false`
  baru jalankan alur lama (bersihkan sesi + `pushAndRemoveUntil` ke `LoginPage`).

---

## Bagian 4 - Flutter: UI ganti akun

### 4.1 AppBar `lib/features/dashboard/main_shell.dart`

Ganti `Chip` outlet (baris 90-96) dengan nama akun:

```dart
InkWell(
  onTap: () => showAccountSwitcherSheet(context),
  borderRadius: BorderRadius.circular(999),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.surfaceAlt,
          child: Icon(Icons.person_outline, size: 16),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            identity, // username, fallback name -> email
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.unfold_more, size: 16, color: AppColors.inkMuted),
      ],
    ),
  ),
),
```

- `maxWidth: 120` + ellipsis -> aman di layar 5,5 inci, tidak overflow meski
  judul halaman panjang.
- `identity` sudah dihitung di baris 77-78, tinggal dipakai.
- Info outlet hilang dari AppBar; tetap terlihat di drawer dan di sheet.

### 4.2 File baru `lib/features/auth/account_switcher_sheet.dart`

```
Ganti Akun
-----------------------------
 (v) (B) Budi Santoso      Kasir
         Outlet Pusat
     (A) Sari              Kasir
         Outlet Cabang
     (C) Andi              Admin
         Tanpa Outlet
-----------------------------
 +  Tambah akun
 x  Keluar dari semua akun   (merah)
```

- Baris aktif: `Icons.check` + background `AppColors.surfaceAlt`.
- Tap akun lain -> kalau shift masih terbuka, dialog konfirmasi *"Shift [nama]
  masih terbuka. Tetap ganti akun?"* -> `switchAccount()`.
- "Keluar dari akun ini" **tidak** ada di sheet (sudah ada di drawer).
- "Tambah akun" -> `LoginPage` mode tambah akun (form kosong, tidak menimpa
  sesi sampai login sukses).
- "Keluar dari semua akun" -> dialog konfirmasi -> `logoutAll()`.

### 4.3 `MainShell` diberi key per user

Di `main.dart`:

```dart
home: _user == null
    ? const LoginPage()
    : MainShell(key: ValueKey(AppData.instance.currentUser?.id)),
```

Supaya `_selectedIndex` dan modal buka-shift ter-reset saat pindah akun, bukan
mewarisi state akun sebelumnya.

### 4.4 Drawer
Tidak diubah. Identitas + ikon logout tetap seperti sekarang.

---

## Bagian 5 - Penyederhanaan warning stok  [SELESAI - 5 Nov 2026]

### 5.1 Katalog POS (`lib/features/pos/pos_catalog_page.dart`) - [x] SELESAI

- [x] **Hapus** `_showStockWarningDialog()` (dulu baris 52-126).
- [x] `_addProduct()` dipersempit menjadi:

```dart
void _addProduct(String productId) => _data.addToCart(productId);
```

- [x] **Pertahankan** `_data.loadProductStock(withDetail: true)` di `initState`.
  Data ini yang dipakai kartu warning di halaman checkout; kalau dihapus,
  warning checkout jadi kosong. Komentar di atasnya sudah disesuaikan agar
  tidak lagi menyebut dialog.

### 5.2 Checkout (`lib/features/pos/pos_checkout_page.dart`) - [x] SELESAI

**Tetap (tidak disentuh):**
- `_cartIssues` getter
- `_buildStockWarningCard()`
- Pemakaiannya di `build()`

**Dihapus:**
- [x] Pemanggilan `_showWarningsSheet(result.warnings)` di `_submit()`
- [x] Seluruh method `_showWarningsSheet()`

Efek: setelah order tersimpan, langsung lanjut ke halaman pembayaran (Bayar
Langsung) atau kembali ke dashboard (Simpan Pesanan), tanpa bottom sheet.

**Penguatan:** [x] `_data.loadProductStock(withDetail: true)` ikut dipanggil di
`initState` checkout (guard `if (!_data.isLoadingStock)`), supaya kartu warning
tidak bergantung pada halaman katalog pernah dibuka.

### 5.3 Yang tidak diubah

- `AppData.stockIssuesFor()` - masih dipakai kartu checkout.
- `CreateOrderResult.warnings` dan model `StockWarning` - tetap ada karena
  backend masih mengirim; hanya tidak ditampilkan lagi.
- Halaman Sisa Stok, dashboard kartu stok kritis - tidak terkait.

### 5.4 Verifikasi

- [x] `flutter analyze` -> `No issues found!`
- [x] `flutter test` -> 15 test lolos, termasuk 2 test baru di
  `test/pos_stock_warning_test.dart`:
  - tombol "Tambah" di katalog tidak memunculkan dialog, tapi produk tetap
    masuk keranjang;
  - kartu "Bahan kurang/habis" tetap tampil di checkout walau stok berdetail
    belum dimuat sebelumnya.

---

## Bagian 6 - Test

| File | Perubahan |
|---|---|
| `test/logout_resilience_test.dart` | Ganti `TokenStorage.saveToken` -> `AccountStore`; sesuaikan ekspektasi kredensial (tanpa password) |
| `test/account_store_test.dart` (baru) | upsert, dedupe by userId, batas 5 + buang `lastUsedAt` terlama, migrasi legacy |
| `test/switch_account_test.dart` (baru) | logout -> auto-switch; 401 -> hanya akun aktif terhapus; token hangus saat switch; `remember=false` tidak tersimpan |
| `test/pos_stock_warning_test.dart` (baru) | tambah produk tidak memunculkan dialog; kartu checkout tetap ada; submit order tanpa bottom sheet |

Jalankan `flutter analyze` dan `flutter test` sebelum selesai.

---

## Bagian 7 - Urutan kerja

1. **Backend**: 1.1 + 1.2 -> uji dengan 2 emulator.
2. **Model + storage**: 2.1, 2.2, 2.3 -> migrasi jalan, belum ada perubahan UI.
3. **Layanan**: 3.1, 3.2, 3.3 -> unit test.
4. **UI ganti akun**: 4.1, 4.2, 4.3.
5. **Warning stok**: 5.1, 5.2. **[SELESAI 5 Nov 2026]**
6. **Test + analyze**. (khusus Bagian 5 sudah dijalankan: analyze bersih, 15 test lolos)

Estimasi: backend ~30 menit; Flutter ~4-5 jam; test ~1 jam.

**Progres:** Bagian 1-6 selesai (5 Nov 2026). Backend juga menolak login
(403) untuk user tanpa outlet — app POS tidak bisa dipakai tanpa outlet.
Tambahan: masa berlaku token Sanctum 30 hari + perintah pembersih token
legacy. Hasil verifikasi: `php artisan test` 39 test lolos; `flutter analyze`
bersih; `flutter test` 27 test lolos. QA manual 2 device oleh user: lolos.

---

## Bagian 8 - Risiko & catatan

1. **Shift masih terbuka** saat ganti akun: shift bersifat per user
   (`ShiftController.php:72,92`). Akun tujuan akan diminta buka shift. Sudah
   ditangani dialog konfirmasi.
2. **Token hangus di akun tersimpan**: user harus mengetik password lagi untuk
   akun itu (konsekuensi pilihan "token saja"). UI menampilkan pesan jelas,
   bukan error generik.
3. **Akun ke-6**: entri paling lama dibuang otomatis; beri info singkat di sheet.
4. **Request berjalan saat ganti akun**: `_fetchProducts` / `_fetchCharges` sudah
   menjaga `_currentUser == null`; tambahkan cek `userId` agar respons akun lama
   tidak menimpa state akun baru.
5. **Token Sanctum tanpa masa berlaku**: multi-device memperbesar risiko token
   bocor. **[SELESAI]** `config/sanctum.php` memakai `SANCTUM_EXPIRATION`
   (default 30 hari).
6. **`/user-info` sebelum diperbaiki** mengembalikan user tanpa `outlet` ->
   jangan lompat langkah 1.2.
