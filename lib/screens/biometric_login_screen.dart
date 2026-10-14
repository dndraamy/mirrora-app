import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/auth_service.dart';
import '../theme/mirrora_theme.dart';
import 'main_navigation.dart';

/// Halaman login dengan fingerprint.
///
/// Dipakai di dua tempat:
/// - Splash, jika sudah ada session dan fingerprint aktif.
/// - Tombol "Login dengan Fingerprint" di halaman Login.
class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({
    super.key,
    required this.userName,
    required this.onUsePassword,
  });

  final String userName;

  /// Dipanggil saat user memilih "Login dengan Password".
  /// Context yang dikirim adalah context halaman ini.
  final void Function(BuildContext context) onUsePassword;

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final AuthService _auth = AuthService();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Langsung munculkan prompt fingerprint begitu halaman terbuka.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  Future<void> _authenticate() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        _setError('Perangkat belum mendukung autentikasi biometrik.');
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifikasi sidik jari untuk masuk ke Mirrora',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        _setError('Verifikasi gagal atau dibatalkan. Coba lagi.');
        return;
      }

      // Fingerprint cocok: pulihkan session dari akun yang terdaftar di Hive.
      final user = await _auth.loginWithBiometric();
      if (!mounted) return;

      if (user == null) {
        _setError('Akun fingerprint tidak ditemukan. Login dengan password.');
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigation(userName: user['username'] as String),
        ),
        (route) => false,
      );
    } on LocalAuthException catch (e) {
      _setError('Fingerprint tidak dapat digunakan: ${e.code.name}');
    } catch (_) {
      _setError('Terjadi kesalahan saat memverifikasi fingerprint.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/mirrora_logo.png',
                      width: 200,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'Mirrora',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.dustyRose,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: GestureDetector(
                      onTap: _authenticate,
                      child: SizedBox(
                        width: 156,
                        height: 156,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: MirroraTheme.blushPink,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: MirroraTheme.dustyRose
                                      .withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                size: 78,
                                color: MirroraTheme.dustyRose,
                              ),
                            ),
                            if (_isLoading)
                              const SizedBox(
                                width: 156,
                                height: 156,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: MirroraTheme.dustyRose,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Halo, ${widget.userName}!',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sentuh sensor sidik jari untuk masuk ke Mirrora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _authenticate,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        _error == null ? 'Gunakan Fingerprint' : 'Coba Lagi',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => widget.onUsePassword(context),
                    child: const Text('Login dengan Password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}