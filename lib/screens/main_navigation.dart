import 'package:flutter/material.dart';

import '../theme/mirrora_theme.dart';
import '../widgets/mirrora_bottom_nav.dart';
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
    // Tab selain Home dan Profil masih placeholder, ganti saat fiturnya dibuat.
    final screens = <Widget>[
      HomeScreen(userName: _userName),
      const _PlaceholderTab(title: 'Explore', icon: Icons.explore_rounded),
      const _PlaceholderTab(
        title: 'AI Beauty Assistant',
        icon: Icons.auto_awesome_rounded,
      ),
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
