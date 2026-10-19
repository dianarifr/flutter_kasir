import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/data/app_data.dart';
import 'core/data/models.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/main_shell.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir App',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      home: _user == null ? const LoginPage() : const MainShell(),
    );
  }
}
