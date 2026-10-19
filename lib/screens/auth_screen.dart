import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/mirrora_theme.dart';
import '../widgets/forgot_password_sheet.dart';
import 'main_navigation.dart';
import 'reset_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _identityController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final LocalAuthentication _localAuth = LocalAuthentication();

  int _selectedTab = 0;

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _biometricEnabled = false;
  bool _hasActiveSession = false;
  bool _isLoading = false;
  bool _isBiometricLoading = false;

  // State setelah register — menunggu konfirmasi email
  bool _awaitingConfirmation = false;
  String _pendingEmail = '';

  // Listener perubahan auth — untuk mendeteksi konfirmasi email via deep link
  StreamSubscription<AuthState>? _authSub;

  bool get isLogin => _selectedTab == 0;

  bool get _showBiometricButton =>
      isLogin && _hasActiveSession && _biometricEnabled;

  // ────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChanged,
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _identityController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────

  Future<void> _loadStatus() async {
    final enabled = Hive.box(
      'settingsBox',
    ).get('mirrora_biometric_enabled', defaultValue: false) as bool;
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled;
      _hasActiveSession = hasSession;
    });
  }

  // Saat user klik link konfirmasi → supabase_flutter fire AuthChangeEvent.signedIn → kita tampilkan dialog sukses lalu navigasi ke home.
  void _onAuthStateChanged(AuthState state) {
    if (!mounted) return;
    if (state.event == AuthChangeEvent.passwordRecovery) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    } else if (state.event == AuthChangeEvent.signedIn && _awaitingConfirmation) {
      final user = state.session?.user;
      if (user == null) return;
      _authSub?.cancel();
      _showEmailConfirmedDialog(user);
    }
  }

  Future<void> _showEmailConfirmedDialog(User user) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: MirroraTheme.white,
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon centang
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: MirroraTheme.blushPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: MirroraTheme.dustyRose,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Email Terkonfirmasi! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Akunmu sudah aktif dan siap digunakan.\nKamu sekarang masuk ke Mirrora.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: MirroraTheme.warmGray,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // tutup dialog
                  _goToHome(user);
                },
                child: const Text(
                  'Mulai Mirrora',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _selectTab(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedTab = index;
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _obscurePassword = true;
      _obscureConfirmPassword = true;
    });
  }

  void _goToHome(User user) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigation(
          userName:
              user.userMetadata?['username'] as String? ??
              user.email?.split('@').first ??
              'Mirrora',
        ),
      ),
      (_) => false,
    );
  }

  // ────────────────────────────────────────────────────────────
  // VALIDATORS
  // ────────────────────────────────────────────────────────────

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bagian ini wajib diisi';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Masukkan alamat email yang valid';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 8) return 'Password minimal 8 karakter';
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }
    if (value != _passwordController.text) return 'Password tidak sama';
    return null;
  }

  // ────────────────────────────────────────────────────────────
  // SUPABASE AUTH
  // ────────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _identityController.text.trim(),
          password: _passwordController.text,
        );

        if (response.user != null && mounted) {
          _goToHome(response.user!);
        }
      } else {
        final username = _usernameController.text.trim();
        final email = _emailController.text.trim();

        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: _passwordController.text,
          data: {'username': username},
          emailRedirectTo: 'mirrora://login-callback/',
        );

        if (!mounted) return;

        if (response.session != null && response.user != null) {
          _showMessage('Registrasi berhasil! Selamat datang di Mirrora.');
          _goToHome(response.user!);
        } else {
          // Supabase mengirim email konfirmasi — tampilkan layar khusus
          setState(() {
            _awaitingConfirmation = true;
            _pendingEmail = email;
          });
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(e.message));
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Terjadi kesalahan koneksi. Periksa internet dan konfigurasi Supabase.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final err = message.toLowerCase();
    if (err.contains('invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (err.contains('user already registered')) {
      return 'Email tersebut sudah terdaftar. Silakan login.';
    }
    if (err.contains('password should be at least')) {
      return 'Password belum memenuhi ketentuan.';
    }
    if (err.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Periksa kotak masuk email kamu.';
    }
    if (err.contains('email rate limit exceeded') ||
        err.contains('rate limit')) {
      return 'Batas pengiriman email tercapai. Silakan coba lagi nanti.';
    }
    if (err.contains('network') || err.contains('socket')) {
      return 'Tidak dapat terhubung ke server. Periksa internet kamu.';
    }
    return message;
  }

  // ────────────────────────────────────────────────────────────
  // BIOMETRIC
  // ────────────────────────────────────────────────────────────

  Future<bool> _authenticateFingerprint() async {
    if (_isBiometricLoading) return false;
    setState(() => _isBiometricLoading = true);

    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canAuthenticate || !isSupported) {
        _showMessage('Perangkat belum mendukung autentikasi biometrik.');
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifikasi sidik jari untuk melanjutkan ke Mirrora',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        _showMessage('Verifikasi fingerprint dibatalkan atau gagal.');
      }
      return authenticated;
    } on LocalAuthException catch (e) {
      _showMessage('Fingerprint tidak dapat digunakan: ${e.code.name}');
      return false;
    } catch (_) {
      _showMessage('Terjadi kesalahan saat memverifikasi fingerprint.');
      return false;
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  Future<void> _loginWithBiometrics() async {
    final enabled = Hive.box(
      'settingsBox',
    ).get('mirrora_biometric_enabled', defaultValue: false) as bool;

    if (!enabled) {
      _showMessage('Aktifkan fingerprint terlebih dahulu.');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _showMessage(
        'Silakan login menggunakan email dan password terlebih dahulu.',
      );
      return;
    }

    final success = await _authenticateFingerprint();
    if (!success || !mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage('Sesi berakhir. Silakan login kembali.');
      return;
    }

    _goToHome(user);
  }

  // ────────────────────────────────────────────────────────────
  // FORGOT PASSWORD
  // ────────────────────────────────────────────────────────────

  void _forgotPassword() {
    ForgotPasswordSheet.show(
      context,
      initialEmail: _identityController.text.trim(),
    );
  }

  // ────────────────────────────────────────────────────────────
  // RESEND CONFIRMATION EMAIL
  // ────────────────────────────────────────────────────────────

  Future<void> _resendConfirmationEmail() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _pendingEmail,
        emailRedirectTo: 'mirrora://login-callback/',
      );
      if (!mounted) return;
      _showMessage('Email konfirmasi dikirim ulang ke $_pendingEmail.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(e.message));
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal mengirim ulang email. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Image.asset(
      'assets/mirrora_logo.png',
      width: 180,
      height: 82,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text(
        'Mirrora',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 31,
          fontWeight: FontWeight.w700,
          color: MirroraTheme.dustyRose,
        ),
      ),
    );
  }

  Widget _buildAwaitingConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 72,
          color: MirroraTheme.dustyRose,
        ),
        const SizedBox(height: 24),
        const Text(
          'Cek Kotak Masuk Email Kamu',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: MirroraTheme.warmGray,
            ),
            children: [
              const TextSpan(text: 'Kami mengirimkan link konfirmasi ke\n'),
              TextSpan(
                text: _pendingEmail,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const TextSpan(
                text:
                    '\n\nKlik link tersebut lalu aplikasi Mirrora akan '
                    'terbuka otomatis dan kamu langsung masuk.\n\n'
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Kirim ulang
        SizedBox(
          width: double.infinity,
          height: 51,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resendConfirmationEmail,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Kirim Ulang Email',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Kembali ke login
        SizedBox(
          width: double.infinity,
          height: 49,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _awaitingConfirmation = false;
                _pendingEmail = '';
                _selectedTab = 0;
              });
              _identityController.clear();
              _passwordController.clear();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: MirroraTheme.dustyRose,
              side: const BorderSide(color: MirroraTheme.blushPink),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Kembali ke Login',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MirroraTheme.charcoal,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: MirroraTheme.dustyRose),
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    onPressed: onToggleVisibility,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? MirroraTheme.dustyRose : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? MirroraTheme.white : MirroraTheme.warmGray,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text(
            isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
            style: const TextStyle(color: MirroraTheme.warmGray, fontSize: 13),
          ),
          GestureDetector(
            onTap: () => _selectTab(isLogin ? 1 : 0),
            child: Text(
              isLogin ? 'Register' : 'Login',
              style: const TextStyle(
                color: MirroraTheme.dustyRose,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildLogo()),
                    if (_awaitingConfirmation)
                      _buildAwaitingConfirmation()
                    else ...[
                      const SizedBox(height: 4),
                      Text(
                        isLogin ? 'Welcome to Mirrora!' : 'Create Your Account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        isLogin
                            ? 'Masuk dan lanjutkan perjalanan self-care-mu.'
                            : 'Mulai perjalanan self-care bersama Mirrora.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: MirroraTheme.warmGray,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Tab Login / Register
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: MirroraTheme.cream,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            _buildTab('Login', 0),
                            _buildTab('Register', 1),
                          ],
                        ),
                      ),
                      const SizedBox(height: 23),

                      // Field email / username + email register
                      if (isLogin) ...[
                        _buildTextField(
                          controller: _identityController,
                          label: 'Email',
                          hint: 'nama@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                      ] else ...[
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Buat username',
                          icon: Icons.person_outline_rounded,
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'nama@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                      ],

                      const SizedBox(height: 15),

                      // Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Masukkan password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        validator: _validatePassword,
                        textInputAction: isLogin
                            ? TextInputAction.done
                            : TextInputAction.next,
                      ),

                      // Konfirmasi password (register saja)
                      if (!isLogin) ...[
                        const SizedBox(height: 15),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Konfirmasi Password',
                          hint: 'Masukkan ulang password',
                          icon: Icons.lock_reset_rounded,
                          obscureText: _obscureConfirmPassword,
                          onToggleVisibility: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                          validator: _validateConfirmation,
                          textInputAction: TextInputAction.done,
                        ),
                      ],

                      // Opsi bawah field — berbeda antara login & register
                      if (isLogin) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            SizedBox(
                              width: 38,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: MirroraTheme.dustyRose,
                                onChanged: (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Expanded(
                              child: Text(
                                'Ingat saya',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: _forgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              child: const Text(
                                'Lupa password?',
                                style: TextStyle(
                                  color: MirroraTheme.dustyRose,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Tombol Login / Register
                      SizedBox(
                        height: 51,
                        child: ElevatedButton(
                          onPressed: _isLoading || _isBiometricLoading
                              ? null
                              : _submitForm,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isLogin ? 'Login' : 'Register',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),

                      // Tombol buka dengan sidik jari hanya muncul jika user sudah pernah login di perangkat ini dan fitur kunci sidik jari sudah diaktifkan.
                      if (_showBiometricButton) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isBiometricLoading
                              ? null
                              : _loginWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded, size: 25),
                          label: Text(
                            _isBiometricLoading
                                ? 'Memverifikasi...'
                                : 'Buka Aplikasi dengan Sidik Jari',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MirroraTheme.dustyRose,
                            minimumSize: const Size(double.infinity, 49),
                            side: const BorderSide(
                              color: MirroraTheme.blushPink,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          isLogin
                              ? 'Lanjutkan perjalanan self-care-mu.'
                              : 'Satu akun untuk perjalanan self-care-mu.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MirroraTheme.warmGray,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                      _buildFooter(),
                    ], // end else
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
