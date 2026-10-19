import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/mirrora_theme.dart';
import 'biometric_login_screen.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';
import 'auth_screen.dart';
import 'reset_password_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authSub;

  void _navigateBasedOnSession() {
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    final settings = Hive.box('settingsBox');
    final biometricEnabled =
        settings.get('mirrora_biometric_enabled', defaultValue: false) as bool;

    late final Widget next;

    if (user == null) {
      next = const OnboardingScreen();
    } else if (biometricEnabled) {
      next = BiometricLoginScreen(
        userName:
            user.userMetadata?['username'] as String? ??
            user.email?.split('@').first ??
            'Mirrora',
        onUsePassword: (ctx) => Navigator.pushReplacement(
          ctx,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        ),
      );
    } else {
      next = MainNavigation(
        userName:
            user.userMetadata?['username'] as String? ??
            user.email?.split('@').first ??
            'Mirrora',
      );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  void initState() {
    super.initState();

    // Listener untuk deep link konfirmasi email — jika Supabase berhasil
    // menukar token sebelum timer habis, langsung navigasi.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _authSub?.cancel();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          );
        } else if (data.event == AuthChangeEvent.signedIn) {
          _authSub?.cancel();
          _navigateBasedOnSession();
        }
      },
    );

    // Timer fallback 2 detik — berjalan bersamaan dengan listener di atas.
    Timer(const Duration(seconds: 2), () {
      _authSub?.cancel();
      _navigateBasedOnSession();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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
          errorBuilder: (_, _, _) => const Text(
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
