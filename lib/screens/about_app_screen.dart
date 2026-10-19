import 'package:flutter/material.dart';

import '../services/admin_auth_service.dart';
import '../theme/mirrora_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const String version = 'v1.0.0 (Build 2026)';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _secretTaps = 0;
  DateTime? _lastTapTime;

  void _handleSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 3)) {
      _secretTaps = 1;
    } else {
      _secretTaps++;
    }
    _lastTapTime = now;

    if (_secretTaps == 3) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Kamu 2 langkah lagi dari Portal Owner...'),
            duration: Duration(milliseconds: 1200),
          ),
        );
    } else if (_secretTaps == 4) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Kamu 1 langkah lagi dari Portal Owner...'),
            duration: Duration(milliseconds: 1200),
          ),
        );
    } else if (_secretTaps >= 5) {
      _secretTaps = 0;
      AdminAuthService().authenticateAndOpenPortal(context);
    }
  }

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
                      'Your AI Beauty & Self-Care Companion',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleSecretTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: MirroraTheme.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Version ${AboutScreen.version}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Mirrora adalah aplikasi asisten kecantikan dan perawatan diri cerdas '
                'yang dirancang untuk membantumu membangun rutinitas harian, '
                'menemukan produk makeup/skincare yang tepat, '
                'serta menemani hari-harimu dengan teknologi AI.',
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
                child: Column(
                  children: [
                    InkWell(
                      onTap: _handleSecretTap,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      child: const _InfoRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Version',
                        value: AboutScreen.version,
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: MirroraTheme.blushPink,
                    ),
                    const _InfoRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Framework',
                      value: 'Flutter',
                    ),
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: MirroraTheme.blushPink,
                    ),
                    const _InfoRow(
                      icon: Icons.storage_rounded,
                      label: 'Database',
                      value: 'Hive (Lokal) & Supabase (Cloud)',
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