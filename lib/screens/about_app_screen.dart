import 'package:flutter/material.dart';

import '../theme/mirrora_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        title: const Text(
          'Tentang Aplikasi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: MirroraTheme.blushPink,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/mirrora_logo.png',
                      width: 190,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'Mirrora',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.dustyRose,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Beauty & Self-Care',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: MirroraTheme.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Versi $version',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MirroraTheme.dustyRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Mirrora adalah aplikasi beauty dan self-care yang membantu '
                'kamu menjaga rutinitas perawatan harian, menemukan produk '
                'yang cocok, dan merawat diri dengan lebih konsisten.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const SizedBox(height: 22),
              Material(
                color: MirroraTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: MirroraTheme.blushPink),
                ),
                child: const Column(
                  children: [
                    _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'Versi',
                      value: version,
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: MirroraTheme.blushPink,
                    ),
                    _InfoRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Dibangun dengan',
                      value: 'Flutter',
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: MirroraTheme.blushPink,
                    ),
                    _InfoRow(
                      icon: Icons.storage_rounded,
                      label: 'Penyimpanan data',
                      value: 'Lokal (Hive)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MirroraTheme.dustyRose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: MirroraTheme.charcoal,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MirroraTheme.warmGray,
            ),
          ),
        ],
      ),
    );
  }
}