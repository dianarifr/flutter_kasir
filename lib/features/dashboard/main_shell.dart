import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/theme/app_colors.dart';
import 'dashboard_page.dart';
import '../pos/pos_catalog_page.dart';
import '../auth/account_switcher_sheet.dart';
import '../orders/order_list_page.dart';
import '../stock/stok_bahan_page.dart';
import '../history/sales_history_page.dart';
import '../receipt/receipt_settings_page.dart';
import '../shift/shift_sheets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  /// Dipakai untuk menutup drawer dari tombol logout di dalamnya.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Shift wajib: begitu masuk app (login / auto-login), muat shift
    // aktif lalu tampilkan modal "Buka Shift" bila belum ada.
    //
    // Ditunda ke post-frame: `loadCurrentShift()` langsung memanggil
    // notifyListeners(), sedangkan `MainShell` dibangun di dalam
    // ListenableBuilder milik `home` — notifikasi saat build memicu
    // assertion framework `'!_dirty': is not true`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureShiftOpen();
    });
    // Teks penutup struk per outlet dimuat dari penyimpanan lokal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppData.instance.loadReceiptFooter();
    });
  }

  Future<void> _ensureShiftOpen() async {
    final data = AppData.instance;
    await data.loadCurrentShift();

    if (!mounted) return;
    // Hanya user ber-outlet yang diingatkan buka shift (admin tanpa
    // outlet dilewati). Modal bisa ditutup — kewajiban shift tetap
    // ditekan di gerbang menu Kasir di bawah.
    if (data.currentOutlet != null && data.currentShift == null) {
      await showOpenShiftSheet(context);
    }
  }

  final List<String> _titles = [
    'Dashboard',
    'Kasir (POS)',
    'Sisa Stok',
    'Daftar Pesanan',
    'Riwayat Penjualan',
    'Pengaturan Struk',
  ];

  final List<Widget> _pages = [
    const DashboardPage(),
    const PosCatalogPage(),
    const StokBahanPage(),
    const OrderListPage(),
    const SalesHistoryPage(),
    const ReceiptSettingsPage(),
  ];

  /// Logout perangkat ini. Bila masih ada akun tersimpan lain, app
  /// otomatis pindah ke akun itu; bila tidak ada, kembali ke login.
  Future<void> _handleLogout() async {
    _scaffoldKey.currentState?.closeDrawer();
    await AppData.instance.logout();

    if (!mounted) return;
    // Tutup halaman yang mungkin masih terbuka di atas shell. Route
    // pertama (home) tetap, isinya sudah diganti lewat ListenableBuilder.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AppData.instance.currentUser;
    // Identitas di drawer: username hasil login (fallback email untuk
    // sesi lama yang belum menyimpan username).
    final identity =
        (user?.username.isNotEmpty ?? false) ? user!.username : (user?.email ?? '-');
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Text(_titles[_selectedIndex]),
        actions: [
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
                      identity,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.unfold_more,
                    size: 16,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.accent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Nyemil Nyam',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  _buildMenuItem(
                    0,
                    Icons.dashboard_outlined,
                    Icons.dashboard,
                    'Dashboard',
                  ),
                  _buildMenuItem(
                    1,
                    Icons.point_of_sale_outlined,
                    Icons.point_of_sale,
                    'Kasir (POS)',
                  ),
                  _buildMenuItem(
                    3,
                    Icons.receipt_long_outlined,
                    Icons.receipt_long,
                    'Daftar Pesanan',
                  ),
                  _buildMenuItem(
                    4,
                    Icons.query_stats_outlined,
                    Icons.query_stats,
                    'Riwayat Penjualan',
                  ),
                  _buildMenuItem(
                    2,
                    Icons.egg_outlined,
                    Icons.egg,
                    'Sisa Stok',
                  ),
                  _buildMenuItem(
                    5,
                    Icons.settings_suggest_outlined,
                    Icons.settings_suggest,
                    'Pengaturan Struk',
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceAlt,
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppData.instance.currentUser?.name ??
                              'Tidak diketahui',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          identity,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: AppColors.error,
                    ),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildMenuItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: AppColors.surfaceAlt,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppColors.accent : AppColors.inkMuted,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.ink : AppColors.inkMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          final data = AppData.instance;
          // Kasir dengan outlet wajib punya shift aktif sebelum masuk
          // POS. Belum ada shift -> bawa ke Dashboard lalu tampilkan
          // modal "Buka Shift". User tanpa outlet (admin) tidak
          // dibatasi, sama seperti gate saat login.
          final butuhShift =
              index == 1 &&
              data.currentOutlet != null &&
              data.currentShift == null;

          setState(() {
            _selectedIndex = butuhShift ? 0 : index;
          });
          Navigator.pop(context);

          if (butuhShift) {
            showOpenShiftSheet(context);
          }
        },
      ),
    );
  }
}
