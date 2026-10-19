import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/token_storage.dart';
import '../../core/theme/app_colors.dart';
import '../dashboard/main_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  bool _isSubmitting = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  /// Prefill form dari kredensial "Ingat saya" yang tersimpan — tetap
  /// terisi walau user baru saja logout (kredensial tidak ikut dibersihkan
  /// saat sesi dihapus).
  Future<void> _loadRememberedCredentials() async {
    final creds = await TokenStorage.readCredentials();
    if (!mounted) return;
    setState(() {
      _rememberMe = creds.remember;
      final email = creds.email;
      final password = creds.password;
      if (email != null) _emailController.text = email;
      if (password != null) _passwordController.text = password;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
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
        email: _emailController.text.trim(),
        password: _passwordController.text,
        remember: _rememberMe,
      );
      AppData.instance.setSession(user);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
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
                        'Kasir POS',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan akun untuk mulai bertransaksi',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // 2. Input Email
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email wajib diisi.';
                              }
                              if (!value.contains('@')) {
                                return 'Format email tidak valid.';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              hintText: 'Masukkan Email',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
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
                          Expanded(
                            child: Text(
                              _rememberMe
                                  ? 'Auto-login saat dibuka lagi'
                                  : 'Login ulang tiap buka app',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkMuted,
                              ),
                              textAlign: TextAlign.right,
                            ),
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
