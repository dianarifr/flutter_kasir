/// Bottom sheet "Ganti Akun" — daftar akun tersimpan di perangkat ini.
library;

import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/account_store.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'login_page.dart';

/// Tampilkan sheet ganti akun dari AppBar.
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends StatefulWidget {
  const _AccountSwitcherSheet();

  @override
  State<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<_AccountSwitcherSheet> {
  List<SavedAccount> _accounts = [];
  int? _activeId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AccountStore.instance.readAccounts();
    final activeId = await AccountStore.instance.readActiveId();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _activeId = activeId;
      _loading = false;
    });
  }

  String _roleLabel(SavedAccount account) =>
      account.user.role == 'admin' ? 'Admin' : 'Kasir';

  String _outletLabel(SavedAccount account) =>
      account.user.outlet?.name ?? 'Tanpa Outlet';

  String _initial(SavedAccount account) {
    final name = account.user.name.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  /// Pindah akun. Bila shift akun saat ini masih terbuka, minta
  /// konfirmasi lebih dulu (shift bersifat per user).
  Future<void> _switchTo(SavedAccount account) async {
    if (_busy || account.userId == _activeId) return;

    final data = AppData.instance;
    if (data.currentShift != null) {
      final currentName = data.currentUser?.name ?? 'Akun ini';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shift masih terbuka'),
          content: Text(
            'Shift $currentName masih terbuka. Tetap ganti akun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ganti Akun'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    try {
      final switched = await AuthService.instance.switchAccount(account.userId);
      if (!mounted) return;
      AppData.instance.switchAccount(switched.user, switched.token);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
      // Token bisa saja sudah dihapus karena 401 — muat ulang daftar.
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat berpindah akun.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Tutup sheet lalu buka form login kosong tanpa menimpa sesi aktif.
  void _addAccount() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => const LoginPage(addAccount: true)),
    );
  }

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari semua akun?'),
        content: const Text(
          'Semua akun di perangkat ini akan dikeluarkan, termasuk di '
          'perangkat lain yang memakai akun yang sama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar Semua'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    await AppData.instance.logoutAll();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ganti Akun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Belum ada akun tersimpan.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final isActive = account.userId == _activeId;
                    return ListTile(
                      enabled: !_busy,
                      tileColor: isActive ? AppColors.surfaceAlt : null,
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? AppColors.accent
                            : AppColors.surfaceAlt,
                        child: Text(
                          _initial(account),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                      title: Text(
                        account.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${_roleLabel(account)} · ${_outletLabel(account)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isActive
                          ? const Icon(
                              Icons.check_circle,
                              size: 20,
                              color: AppColors.accent,
                            )
                          : null,
                      onTap: () => _switchTo(account),
                    );
                  },
                ),
              ),
            if (!_loading && _accounts.length >= AccountStore.maxAccounts)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  'Maksimal 5 akun — akun yang paling lama tidak dipakai '
                  'akan dilepas otomatis.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            const Divider(height: 1),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.add, size: 20),
              title: const Text('Tambah akun', style: TextStyle(fontSize: 14)),
              onTap: _addAccount,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.error,
              ),
              title: const Text(
                'Keluar dari semua akun',
                style: TextStyle(fontSize: 14, color: AppColors.error),
              ),
              onTap: _logoutAll,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}