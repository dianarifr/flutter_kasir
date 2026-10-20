import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/data/app_data.dart';
import 'core/data/models.dart';
import 'core/network/api_client.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/main_shell.dart';

/// Kunci navigator global — dipakai handler sesi hangus untuk
/// mengarahkan user ke halaman login dari halaman manapun.
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
  /// `null` = masih memeriksa sesi tersimpan (tampilkan splash).
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _restoreSession();

    // Sesi hangus di tengah pemakaian (401): langsung ke halaman login
    // agar user jelas harus login ulang, bukan hanya melihat pesan error.
    ApiClient.instance.onUnauthorized = _handleSessionExpired;
  }

  /// Coba pulihkan sesi dari penyimpanan lokal (auto-login).
  Future<void> _restoreSession() async {
    final user = await AuthService.instance.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = user;
      if (user != null) AppData.instance.setSession(user);
    });
  }

  /// Sesi hangus (token invalid/kadaluarsa): bersihkan sesi lokal lalu
  /// ganti seluruh tumpukan halaman dengan halaman login, disertai
  /// keterangan alasannya.
  Future<void> _handleSessionExpired() async {
    await AppData.instance.clearSessionLocal();
    if (!mounted) return;

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );

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
      home: _user == null ? const LoginPage() : const MainShell(),
    );
  }
}
