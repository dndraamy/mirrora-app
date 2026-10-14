import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/mirrora_theme.dart';
import 'about_app_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _biometricHiveKey = 'mirrora_biometric_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricOn = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final enabled =
        Hive.box('settingsBox').get(_biometricHiveKey, defaultValue: false)
            as bool;
    if (!mounted) return;
    setState(() => _biometricOn = enabled);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      // Pastikan Supabase session masih aktif.
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser == null) {
        _showMessage('Sesi tidak ditemukan. Silakan login ulang.');
        return;
      }

      if (enable) {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();

        if (!canCheck || !isSupported) {
          _showMessage('Perangkat belum mendukung autentikasi biometrik.');
          return;
        }

        // Verifikasi sidik jari dulu sebelum fitur diaktifkan.
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verifikasi sidik jari untuk mengaktifkan login',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (!authenticated) {
          _showMessage('Verifikasi dibatalkan. Login biometric belum aktif.');
          return;
        }

        await Hive.box('settingsBox').put(_biometricHiveKey, true);
        if (!mounted) return;
        setState(() => _biometricOn = true);
        _showMessage('Login biometric diaktifkan.');
      } else {
        await Hive.box('settingsBox').put(_biometricHiveKey, false);
        if (!mounted) return;
        setState(() => _biometricOn = false);
        _showMessage('Login biometric dinonaktifkan.');
      }
    } on LocalAuthException catch (e) {
      _showMessage('Fingerprint tidak dapat digunakan: ${e.code.name}');
    } catch (e) {
      debugPrint('Biometric toggle error: $e');
      _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Atur akun dan preferensi aplikasimu',
              style: TextStyle(fontSize: 13, color: MirroraTheme.warmGray),
            ),
            const SizedBox(height: 26),

            // ------------------------------------------------------- AKUN
            const _SectionLabel('Akun'),
            _SettingsCard(
              children: [
                _SettingTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Ubah Password',
                  subtitle: 'Perbarui kata sandi akunmu',
                  onTap: () => _open(
                    const _PlaceholderTab(
                      title: 'Ubah Password',
                      icon: Icons.lock_outline_rounded,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // -------------------------------------------------- KEAMANAN
            const _SectionLabel('Keamanan'),
            _SettingsCard(
              children: [
                _SettingTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Login Biometric',
                  subtitle: _biometricOn
                      ? 'Aktif - masuk dengan sidik jari'
                      : 'Nonaktif',
                  trailing: Switch(
                    value: _biometricOn,
                    onChanged: _isBusy ? null : _toggleBiometric,
                    activeThumbColor: MirroraTheme.white,
                    activeTrackColor: MirroraTheme.dustyRose,
                    inactiveThumbColor: MirroraTheme.white,
                    inactiveTrackColor: MirroraTheme.warmGray.withValues(
                      alpha: 0.35,
                    ),
                    trackOutlineColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                  ),
                  onTap: _isBusy ? null : () => _toggleBiometric(!_biometricOn),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Text(
                'Saat aktif, kamu bisa masuk ke Mirrora memakai sidik jari '
                'tanpa mengetik password. Sidik jari yang dipakai adalah '
                'yang terdaftar di perangkatmu.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: MirroraTheme.warmGray,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ----------------------------------------------- PREFERENSI
            const _SectionLabel('Preferensi'),
            _SettingsCard(
              children: [
                _SettingTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifikasi',
                  subtitle: 'Atur pengingat rutinitas',
                  onTap: () => _open(
                    const _PlaceholderTab(
                      title: 'Notifikasi',
                      icon: Icons.notifications_none_rounded,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // -------------------------------------------------- LAINNYA
            const _SectionLabel('Lainnya'),
            _SettingsCard(
              children: [
                _SettingTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang Aplikasi',
                  subtitle: 'Versi ${AboutScreen.version}',
                  onTap: () => _open(const AboutScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ WIDGETS

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: MirroraTheme.dustyRose,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MirroraTheme.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: MirroraTheme.blushPink),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 23, color: MirroraTheme.dustyRose),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MirroraTheme.warmGray,
                ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: MirroraTheme.blushPink,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: MirroraTheme.dustyRose),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Segera hadir',
              style: TextStyle(fontSize: 13, color: MirroraTheme.warmGray),
            ),
          ],
        ),
      ),
    );
  }
}
