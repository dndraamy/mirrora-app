import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'theme/mirrora_theme.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settingsBox');

  await Supabase.initialize(
    url: 'https://paeuxgviqbajuitsosuq.supabase.co',
    publishableKey: 'sb_publishable_OcM3vYtlHeqf8zBiZc_0jQ_3XRt8GDO',
  );

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
