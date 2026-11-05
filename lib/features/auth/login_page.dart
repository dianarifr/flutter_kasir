import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/data/app_data.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/token_storage.dart';
import '../../core/theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.addAccount = false});

  /// `true` = dibuka dari sheet "Tambah akun": sesi aktif tidak
  /// ditimpa sampai login berhasil, lalu halaman ini ditutup.
  final bool addAccount;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  bool _isSubmitting = false;
  bool _rememberMe = true;

  /// Label versi app, mis. `v1.1.0 (7)` — dibaca runtime dari
  /// package_info_plus (versionName + versionCode), bukan di-hardcode.
  /// Kosong bila belum termuat / gagal dibaca (teks tak tampil).
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    if (!widget.addAccount) _loadRememberedUsername();
    _loadAppVersion();
  }

  /// Baca versi app dari platform untuk ditampilkan kecil di bawah
  /// tombol Masuk. Kegagalan (mis. di unit test) diabaikan — label
  /// versi hanya informasi.
  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(
        () => _versionLabel = 'v${info.version} (${info.buildNumber})',
      );
    } catch (_) {
      // Biarkan kosong.
    }
  }

  /// Prefill username dari "Ingat saya". Password tidak pernah disimpan.
  /// Pada mode tambah akun form sengaja kosong.
  Future<void> _loadRememberedUsername() async {
    final remembered = await TokenStorage.readRemembered();
    if (!mounted) return;
    setState(() {
      _rememberMe = remembered.remember;
      final username = remembered.username;
      if (username != null) _usernameController.text = username;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Kirim kredensial ke backend dan pindah ke halaman utama bila sukses.
  Future<void> _submit() async {
    // Validasi form lokal dulu sebelum menyentuh API.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final user = await AuthService.instance.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        remember: _rememberMe,
      );
      AppData.instance.setSession(user);

      if (!mounted) return;
      if (widget.addAccount) {
        // Kembali ke layar utama; ListenableBuilder sudah memakai akun
        // baru karena AppData.setSession memicu rebuild.
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Logo / Minimalist Store Icon (Tengah)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 32,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        widget.addAccount ? 'Tambah Akun' : 'Nyemil Nyam',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.addAccount
                            ? 'Masuk ke akun lain tanpa keluar dari akun ini'
                            : 'Masukkan akun untuk mulai bertransaksi',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // 2. Input Username
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Username',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username wajib diisi.';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              hintText: 'Masukkan Username',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. Input Password
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kata Sandi',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _isObscure,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password wajib diisi.';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'Masukkan Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isObscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscure = !_isObscure;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 4. Remember me
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _isSubmitting
                                ? null
                                : (value) => setState(
                                    () => _rememberMe = value ?? true,
                                  ),
                          ),
                          const Text(
                            'Ingat saya',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. Tombol Login
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Masuk'),
                        ),
                      ),

                      // Versi app — kecil, hanya informasi.
                      if (_versionLabel.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          _versionLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
