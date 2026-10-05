import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_colors.dart';

void main() {
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir App',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      home: const ThemePreviewPage(),
    );
  }
}

class ThemePreviewPage extends StatelessWidget {
  const ThemePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Tema Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          // PERBAIKAN DI SINI: CrossAxisAlignment
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pandugo Outlet', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text('Katalog Menu Kasir', style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),

            Row(
              children: [
                Chip(
                  label: const Text('Semua'),
                  backgroundColor: theme.colorScheme.primary,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Chip(label: Text('Dimsum')),
                const SizedBox(width: 8),
                const Chip(label: Text('Minuman')),
              ],
            ),
            const SizedBox(height: 24),

            const TextField(
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        // PERBAIKAN DI SINI: CrossAxisAlignment
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dimsum Besar Mentai 8', style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text('Rp 35.000', style: AppTextStyles.priceTag),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Bayar Sekarang'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}