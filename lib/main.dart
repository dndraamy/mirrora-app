import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart';
import 'services/currency_service.dart';
import 'services/giveaway_service.dart';
import 'services/notification_service.dart';
import 'theme/mirrora_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://paeuxgviqbajuitsosuq.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhZXV4Z3ZpcWJhanVpdHNvc3VxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5NjIyOTMsImV4cCI6MjEwNzUzODI5M30.5z0zFRD707CFXy4bCEYB5SWV0bQY5iWhejDIbsJ3U5c',
  );

  await Hive.initFlutter();
  await Hive.openBox('settingsBox');
  await CurrencyService().init();
  await GiveawayService().init();
  await NotificationService().init();
  await NotificationService().requestPermissions();

  runApp(const MirroraApp());
}

class MirroraApp extends StatefulWidget {
  const MirroraApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MirroraApp> createState() => _MirroraAppState();
}

class _MirroraAppState extends State<MirroraApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        MirroraApp.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MirroraApp.navigatorKey,
      title: 'Mirrora',
      debugShowCheckedModeBanner: false,
      theme: MirroraTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/reset-password': (_) => const ResetPasswordScreen(),
      },
    );
  }
}
