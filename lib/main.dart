import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/data/app_data.dart';
import 'core/network/api_client.dart';
import 'core/services/account_store.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/main_shell.dart';

/// Kunci navigator global — dipakai handler sesi hangus untuk menutup
/// halaman yang sedang terbuka dari halaman mana pun.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Muat konfigurasi dari file .env (API_BASE_URL dkk).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env tidak ditemukan/gagal dibaca: tidak ada lagi fallback URL
    // hardcode — ApiConfig.baseUrl akan melempar StateError dengan
    // petunjuk perbaikan saat request pertama dibuat.
  }
  runApp(const PosApp());
}

class PosApp extends StatefulWidget {
  const PosApp({super.key});

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  /// `true` = masih memulihkan sesi tersimpan (tampilkan splash).
  bool _isRestoring = true;

  @override
  void initState() {
    super.initState();
    // Pasang handler sebelum restore: validasi token di latar juga bisa 401.
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
    _restoreSession();
  }

  /// Pulihkan sesi dari daftar akun tersimpan (auto-login).
  Future<void> _restoreSession() async {
    final user = await AuthService.instance.restoreSession();
    if (!mounted) return;
    if (user != null) AppData.instance.setSession(user);
    setState(() => _isRestoring = false);
  }

  /// Sesi hangus (token invalid/kadaluarsa).
  ///
  /// Bila ada akun lain tersimpan, pindah diam-diam dan jangan ganggu
  /// user. Bila tidak ada, tutup semua halaman dan tampilkan login.
  Future<bool> _handleUnauthorized() async {
    final switched = await AuthService.instance.handleUnauthorized();

    if (switched) {
      final active = await AccountStore.instance.readActive();
      if (active != null) {
        AppData.instance.switchAccount(active.user, active.token);
      }
      return true;
    }

    await AppData.instance.clearSessionLocal();
    if (!mounted) return false;

    navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // Keterangan muncul di halaman login — tunggu frame berikutnya agar
    // Scaffold LoginPage sudah terpasang.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi berakhir, silakan login kembali.'),
          backgroundColor: AppColors.error,
        ),
      );
    });

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Nyemil Nyam',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      // Reaktif terhadap ganti akun: login/logout/switch langsung
      // mengganti layar tanpa navigasi manual.
      home: ListenableBuilder(
        listenable: AppData.instance,
        builder: (context, _) {
          if (_isRestoring) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = AppData.instance.currentUser;
          return user == null
              ? const LoginPage()
              : MainShell(key: ValueKey(user.id));
        },
      ),
    );
  }
}