import 'package:flutter/material.dart';

import '../theme/mirrora_theme.dart';
import 'auth_screen.dart';

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
      'icon': 'face',
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
      case 'face':
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
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
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
                          width: 190,
                          height: 190,
                          decoration: const BoxDecoration(
                            color: MirroraTheme.blushPink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForPage(page['icon']!),
                            size: 88,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                        const SizedBox(height: 34),
                        Text(
                          page['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 14),
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
              const SizedBox(height: 26),
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
