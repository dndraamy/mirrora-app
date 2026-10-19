import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_auth_service.dart';
import '../theme/mirrora_theme.dart';
import 'about_app_screen.dart';
import 'change_password_screen.dart';

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
    final enabled = Hive.box(
      'settingsBox',
    ).get(_biometricHiveKey, defaultValue: false) as bool;
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

  int _secretTapCount = 0;
  DateTime? _lastSecretTap;

  void _onSecretTap() {
    final now = DateTime.now();
    if (_lastSecretTap == null || now.difference(_lastSecretTap!) > const Duration(seconds: 3)) {
      _secretTapCount = 1;
    } else {
      _secretTapCount++;
    }
    _lastSecretTap = now;

    if (_secretTapCount == 3) {
      _showMessage('Kamu 2 langkah lagi dari Portal Owner...');
    } else if (_secretTapCount == 4) {
      _showMessage('Kamu 1 langkah lagi dari Portal Owner...');
    } else if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      AdminAuthService().authenticateAndOpenPortal(context);
    }
  }

  void _openAdminPortal() {
    AdminAuthService().authenticateAndOpenPortal(context);
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
        // Cek apakah hardware biometrik tersedia di perangkat ini.
        final isSupported = await _localAuth.isDeviceSupported();
        if (!isSupported) {
          _showErrorDialog(
            judul: 'Perangkat Tidak Didukung',
            pesan:
                'Perangkat ini tidak memiliki sensor sidik jari atau wajah. '
                'Fitur kunci sidik jari tidak dapat digunakan.',
          );
          return;
        }

        // Cek apakah ada sidik jari / wajah yang sudah terdaftar di HP.
        final canCheck = await _localAuth.canCheckBiometrics;
        if (!canCheck) {
          _showErrorDialog(
            judul: 'Sidik Jari Belum Terdaftar',
            pesan:
                'Kamu belum mendaftarkan sidik jari di pengaturan perangkat ini.\n\n'
                'Buka Pengaturan → Keamanan → Sidik Jari, '
                'tambahkan sidik jari, lalu kembali ke sini untuk mengaktifkan fitur ini.',
          );
          return;
        }

        // Verifikasi sidik jari dulu sebelum fitur diaktifkan.
        final authenticated = await _localAuth.authenticate(
          localizedReason:
              'Verifikasi sidik jari untuk mengaktifkan kunci aplikasi',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (!authenticated) {
          _showMessage('Verifikasi dibatalkan. Kunci sidik jari belum aktif.');
          return;
        }

        await Hive.box('settingsBox').put(_biometricHiveKey, true);
        if (!mounted) return;
        setState(() => _biometricOn = true);
        _showMessage('Kunci sidik jari diaktifkan.');
      } else {
        await Hive.box('settingsBox').put(_biometricHiveKey, false);
        if (!mounted) return;
        setState(() => _biometricOn = false);
        _showMessage('Kunci sidik jari dinonaktifkan.');
      }
    } on LocalAuthException catch (e) {
      final pesan = _pesanDariKodeError(e.code);
      // Pesan kosong artinya user yang membatalkan — tidak perlu dialog.
      if (pesan.isNotEmpty) {
        _showErrorDialog(judul: 'Tidak Dapat Menggunakan Sidik Jari', pesan: pesan);
      }
    } catch (e) {
      debugPrint('Biometric toggle error: $e');
      _showMessage('Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Menampilkan dialog error yang tidak bisa diabaikan begitu saja,
  /// cocok untuk kondisi yang butuh tindakan dari user.
  void _showErrorDialog({required String judul, required String pesan}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.fingerprint_rounded, color: MirroraTheme.dustyRose),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                judul,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          pesan,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: MirroraTheme.warmGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                color: MirroraTheme.dustyRose,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Memetakan kode error LocalAuthException ke pesan yang mudah dipahami.
  String _pesanDariKodeError(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Perangkat ini tidak memiliki sensor sidik jari atau wajah. '
            'Fitur kunci sidik jari tidak dapat digunakan.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'Belum ada sidik jari atau wajah yang terdaftar di perangkat ini.\n\n'
            'Buka Pengaturan → Keamanan → Sidik Jari, lalu tambahkan sidik jari kamu.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Perangkat belum memiliki kunci layar (PIN, pola, atau sidik jari) '
            'yang dikonfigurasi.\n\nAktifkan kunci layar di Pengaturan terlebih dahulu.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Terlalu banyak percobaan yang gagal. '
            'Autentikasi sidik jari dikunci sementara.\n\n'
            'Tunggu beberapa saat, lalu coba lagi.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Sidik jari dikunci karena terlalu banyak percobaan gagal.\n\n'
            'Buka kunci perangkat menggunakan PIN atau pola terlebih dahulu, '
            'lalu coba lagi.';
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Sensor sidik jari sedang tidak tersedia sementara. '
            'Coba lagi dalam beberapa saat.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        // Dibatalkan user atau sistem — tidak perlu dialog.
        return '';
      default:
        return 'Terjadi masalah saat mengakses sidik jari. '
            'Pastikan sidik jari sudah terdaftar dan coba lagi.';
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
                  onTap: () => _open(const ChangePasswordScreen()),
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
                  title: 'Kunci Sidik Jari',
                  subtitle: _biometricOn
                      ? 'Aktif — sidik jari diperlukan saat membuka app'
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
                'Saat aktif, kamu akan diminta verifikasi sidik jari '
                'setiap kali membuka aplikasi Mirrora untuk '
                'menjaga keamanan akunmu. ',
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
                  onTap: () {
                    _onSecretTap();
                    _open(const AboutScreen());
                  },
                ),
                if (!AdminAuthService().isStealthMode())
                  _SettingTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Portal Undian (Owner / Admin) 🛡️',
                    subtitle: 'Terlindungi Biometrik & SHA-256',
                    onTap: _openAdminPortal,
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
