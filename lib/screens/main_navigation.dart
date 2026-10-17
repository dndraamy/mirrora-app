import 'package:flutter/material.dart';

import '../theme/mirrora_theme.dart';
import '../widgets/mirrora_bottom_nav.dart';
import 'ai_assistant_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Container utama setelah login: 5 tab (Home, Explore, AI, Profil, Settings).
class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.userName = 'Sarah',
  });

  final int initialIndex;
  final String userName;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex = widget.initialIndex;
  late String _userName = widget.userName;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(userName: _userName),
      const ExploreScreen(),
      AiAssistantScreen(userName: _userName),
      ProfileScreen(
        userName: _userName,
        onProfileChanged: (name) => setState(() => _userName = name),
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      // IndexedStack menjaga state tiap tab saat berpindah.
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: MirroraBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
