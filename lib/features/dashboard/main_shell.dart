import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/theme/app_colors.dart';
import 'dashboard_page.dart';
import '../pos/pos_catalog_page.dart';
import '../auth/login_page.dart';
import '../orders/order_list_page.dart';
import '../stock/stok_bahan_page.dart';
import '../stock/stok_produk_page.dart';
import '../history/sales_history_page.dart';
import '../shift/shift_sheets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Shift wajib: begitu masuk app (login / auto-login), muat shift
    // aktif lalu tampilkan modal "Buka Shift" bila belum ada.
    _ensureShiftOpen();
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
    'Stok Produk',
    'Stok Bahan',
    'Daftar Pesanan',
    'Riwayat Penjualan',
  ];

  final List<Widget> _pages = [
    const DashboardPage(),
    const PosCatalogPage(),
    const StokProdukPage(),
    const StokBahanPage(),
    const OrderListPage(),
    const SalesHistoryPage(),
  ];

  /// Logout: panggil API, bersihkan state, lalu kembali ke halaman login.
  Future<void> _handleLogout() async {
    await AppData.instance.logout();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
          Chip(
            avatar: const Icon(Icons.store_outlined, size: 16),
            label: Text(AppData.instance.currentOutlet?.name ?? 'Tanpa Outlet'),
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
                    4,
                    Icons.receipt_long_outlined,
                    Icons.receipt_long,
                    'Daftar Pesanan',
                  ),
                  _buildMenuItem(
                    5,
                    Icons.query_stats_outlined,
                    Icons.query_stats,
                    'Riwayat Penjualan',
                  ),
                  _buildMenuItem(
                    3,
                    Icons.egg_outlined,
                    Icons.egg,
                    'Stok Bahan',
                  ),
                  _buildMenuItem(
                    2,
                    Icons.inventory_2_outlined,
                    Icons.inventory_2,
                    'Stok Produk',
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
                          AppData.instance.currentUser?.email ?? '-',
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
