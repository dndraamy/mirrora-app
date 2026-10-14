import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'screens/biometric_login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/auth_service.dart';
import 'theme/mirrora_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const MirroraApp());
}

class MirroraApp extends StatelessWidget {
  const MirroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirrora',
      debugShowCheckedModeBanner: false,
      theme: MirroraTheme.lightTheme,
      home: const SplashScreen(),
      routes: {'/auth': (_) => const AuthScreen()},
    );
  }
}

// ============================================================
// SPLASH SCREEN
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () async {
      final auth = AuthService();
      final user = await auth.currentUser();
      final bioUser = auth.biometricUser();
      if (!mounted) return;

      final Widget next;
      if (user == null) {
        next = const OnboardingScreen();
      } else if (bioUser != null && bioUser['email'] == user['email']) {
        // Ada session + fingerprint aktif: minta verifikasi dulu.
        next = BiometricLoginScreen(
          userName: user['username'] as String,
          onUsePassword: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          ),
        );
      } else {
        next = MainNavigation(userName: user['username'] as String);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.white,
      body: Center(
        child: Image.asset(
          'assets/mirrora_logo.png',
          width: 300,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'Mirrora',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w600,
              color: MirroraTheme.dustyRose,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ONBOARDING SCREEN
// ============================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Discover Your Beauty',
      'description':
          'Kenali dirimu lebih dalam dan temukan rutinitas yang cocok untukmu.',
      'icon': 'face_retouching_natural',
    },
    {
      'title': 'Your Personal Space',
      'description':
          'Simpan preferensi dan perjalanan perawatanmu dalam satu tempat.',
      'icon': 'spa',
    },
    {
      'title': 'Glow With Confidence',
      'description':
          'Mulai perjalanan merawat diri dengan cara yang lebih personal.',
      'icon': 'favorite',
    },
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _openAuth();
    }
  }

  void _openAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  IconData _iconForPage(String name) {
    switch (name) {
      case 'face_retouching_natural':
        return Icons.face_retouching_natural;
      case 'spa':
        return Icons.spa_outlined;
      default:
        return Icons.favorite_border_rounded;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _openAuth,
                  child: const Text(
                    'Lewati',
                    style: TextStyle(color: MirroraTheme.warmGray),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 210,
                          height: 210,
                          decoration: const BoxDecoration(
                            color: MirroraTheme.blushPink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForPage(page['icon']!),
                            size: 100,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                        const SizedBox(height: 42),
                        Text(
                          page['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: MirroraTheme.warmGray,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 25 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? MirroraTheme.dustyRose
                          : MirroraTheme.blushPink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Mulai Sekarang'
                        : 'Lanjutkan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN & REGISTER SCREEN
// ============================================================

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
  bool _isBiometricLoading = false;
  bool _isSubmitting = false;
  final AuthService _auth = AuthService();

  bool get isLogin => _selectedTab == 0;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  void _loadBiometricStatus() {
    _biometricEnabled = _auth.biometricUser() != null;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bagian ini wajib diisi';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email wajib diisi';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(value.trim())) {
      return 'Masukkan alamat email yang valid';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }

    if (value.length < 8) {
      return 'Password minimal 8 karakter';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }

    if (value != _passwordController.text) {
      return 'Password tidak sama';
    }

    return null;
  }

  Future<bool> _authenticateFingerprint() async {
    if (_isBiometricLoading) return false;

    setState(() => _isBiometricLoading = true);

    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canAuthenticate || !isDeviceSupported) {
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
      if (mounted) {
        setState(() => _isBiometricLoading = false);
      }
    }
  }

  Future<void> _enableBiometrics(String email) async {
    final success = await _authenticateFingerprint();

    if (!success || !mounted) return;

    try {
      await _auth.enableBiometric(email);

      if (!mounted) return;

      setState(() => _biometricEnabled = true);

      _showMessage('Fingerprint berhasil diaktifkan di perangkat ini.');
    } catch (_) {
      _showMessage(
        'Fingerprint terverifikasi, tetapi statusnya gagal disimpan.',
      );
    }
  }

  void _loginWithBiometrics() {
    final user = _auth.biometricUser();

    if (user == null) {
      _showMessage(
        'Aktifkan fingerprint melalui menu Register terlebih dahulu.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BiometricLoginScreen(
          userName: user['username'] as String,
          onUsePassword: (ctx) => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      _showMessage('Konfirmasi password tidak cocok.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (isLogin) {
        final user = await _auth.login(
          identity: _identityController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        _openDashboard(user['username'] as String);
      } else {
        final user = await _auth.register(
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        await _enableBiometrics(user['email'] as String);
        if (!mounted) return;
        _openDashboard(user['username'] as String);
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openDashboard(String userName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainNavigation(userName: userName)),
    );
  }

  void _selectTab(int index) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedTab = index;
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/mirrora_logo.png',
      width: 280,
      height: 140,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Text(
        'Mirrora',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: MirroraTheme.dustyRose,
        ),
      ),
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
        const SizedBox(height: 9),
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
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: MirroraTheme.charcoal,
          side: const BorderSide(color: MirroraTheme.blushPink),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identityController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 18, 26, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildLogo()),
                    const SizedBox(height: 10),
                    Text(
                      isLogin ? 'Welcome to Mirrora' : 'Create Your Account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin
                          ? 'Masuk dan lanjutkan perjalanan merawat dirimu.'
                          : 'Mulai perjalanan self-care bersama Mirrora.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: MirroraTheme.warmGray,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // LOGIN / REGISTER TABS
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
                    const SizedBox(height: 25),

                    if (isLogin) ...[
                      _buildTextField(
                        controller: _identityController,
                        label: 'Email atau Username',
                        hint: 'Masukkan email atau username',
                        icon: Icons.person_outline_rounded,
                        validator: _validateRequired,
                      ),
                    ] else ...[
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Buat username',
                        icon: Icons.person_outline_rounded,
                        validator: _validateRequired,
                      ),
                      const SizedBox(height: 17),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'nama@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                    ],

                    const SizedBox(height: 17),

                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Masukkan password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      validator: _validatePassword,
                      textInputAction: isLogin
                          ? TextInputAction.done
                          : TextInputAction.next,
                    ),

                    if (!isLogin) ...[
                      const SizedBox(height: 17),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Konfirmasi Password',
                        hint: 'Masukkan ulang password',
                        icon: Icons.lock_reset_rounded,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        validator: _validateConfirmation,
                        textInputAction: TextInputAction.done,
                      ),
                    ],

                    if (isLogin) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: MirroraTheme.dustyRose,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Ingat saya',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _showMessage(
                                'Fitur lupa password belum dihubungkan.',
                              );
                            },
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
                    ] else ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.fingerprint_rounded,
                            color: MirroraTheme.dustyRose,
                            size: 22,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _biometricEnabled
                                  ? 'Fingerprint sudah diaktifkan pada perangkat ini.'
                                  : 'Setelah validasi form, kamu dapat mengaktifkan '
                                        'fingerprint pada perangkat ini.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: MirroraTheme.warmGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // PRIMARY BUTTON
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isBiometricLoading || _isSubmitting)
                            ? null
                            : _submitForm,
                        child: (_isBiometricLoading || _isSubmitting)
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

                    // BIOMETRIC LOGIN BUTTON
                    if (isLogin) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _isBiometricLoading
                            ? null
                            : _loginWithBiometrics,
                        icon: const Icon(Icons.fingerprint_rounded, size: 26),
                        label: const Text('Login dengan Fingerprint'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MirroraTheme.dustyRose,
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: MirroraTheme.blushPink),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: MirroraTheme.blushPink),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'atau lanjutkan dengan',
                            style: TextStyle(
                              color: MirroraTheme.warmGray,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: MirroraTheme.blushPink),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        _buildSocialButton(
                          label: 'Google',
                          icon: Icons.g_mobiledata_rounded,
                          onPressed: () {
                            _showMessage('Login Google belum dihubungkan.');
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildSocialButton(
                          label: 'Apple',
                          icon: Icons.apple,
                          onPressed: () {
                            _showMessage('Login Apple belum dihubungkan.');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                          style: const TextStyle(
                            color: MirroraTheme.warmGray,
                            fontSize: 13,
                          ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
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
            ),
          ),
        ),
      ),
    );
  }
}
