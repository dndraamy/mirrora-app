import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mirrora_theme.dart';

class KesanSaranScreen extends StatefulWidget {
  const KesanSaranScreen({super.key});

  @override
  State<KesanSaranScreen> createState() => _KesanSaranScreenState();
}

class _KesanSaranScreenState extends State<KesanSaranScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _tapBounceController;
  late final AnimationController _cardEntranceController;

  int _reactionIndex = 0;
  final List<String> _reactions = [
    'Seger tapi dingin banget! 🧊',
    'Sensasi dingin yang membekukan waktu! ⏰',
    'Racikan teh penuh perjuangan & begadang! 🍵',
    'Tetap manis walau sempat kena freeze! ✨',
  ];

  @override
  void initState() {
    super.initState();
    // Animasi mengambang / bobbing es batu & uap dingin secara berkelanjutan
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Animasi bounce ketika es teh diketuk oleh user
    _tapBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Animasi masuk untuk kartu
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _tapBounceController.dispose();
    _cardEntranceController.dispose();
    super.dispose();
  }

  void _onTapEsTeh() {
    HapticFeedback.lightImpact();
    setState(() {
      _reactionIndex = (_reactionIndex + 1) % _reactions.length;
    });
    _tapBounceController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: MirroraTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MirroraTheme.blushPink),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: MirroraTheme.charcoal,
              ),
            ),
          ),
        ),
        title: const Text(
          'Kesan & Saran',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // HERO ANIMATED ES TEH SECTION
              // ==========================================
              GestureDetector(
                onTap: _onTapEsTeh,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: MirroraTheme.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: MirroraTheme.blushPink),
                    boxShadow: [
                      BoxShadow(
                        color: MirroraTheme.dustyRose.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Speech Bubble / Reaksi Lucu
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: Container(
                          key: ValueKey(_reactionIndex),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: MirroraTheme.blushPink,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: MirroraTheme.dustyRose.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            _reactions[_reactionIndex],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MirroraTheme.dustyRose,
                            ),
                          ),
                        ),
                      ),

                      // Animated Cup Illustration
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                          CurvedAnimation(
                            parent: _tapBounceController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _floatController,
                          builder: (context, child) {
                            return _AnimatedEsTehCup(
                              floatProgress: _floatController.value,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Caption
                      const Text(
                        'Racikan Es Teh Mirrora',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 13,
                            color: MirroraTheme.warmGray.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ketuk es teh untuk mengocok es batu 🧊',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: MirroraTheme.warmGray.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ==========================================
              // KESAN CARD
              // ==========================================
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _cardEntranceController,
                        curve: const Interval(
                          0.1,
                          0.7,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _cardEntranceController,
                    curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
                  ),
                  child: _buildFeedbackCard(
                    title: 'Kesan',
                    tagline: 'Refleksi Perjalanan Coding di Balik Layar',
                    content: 'Pengerjaan project mobile ini hadir bak seteguk es teh di tengah teriknya dinamika perkuliahan. Namun, kejutan rasa hadir di setiap sedotannya—es batunya menjelma begitu dominan hingga kehangatan racikan tehnya perlahan tersamarkan. Sensasi "dingin" yang ditawarkan tak sekadar menyejukkan, melainkan sanggup membekukan waktu; memaksa kami terjaga di sunyinya malam, merangkai widget demi widget, serta menuntun setiap error yang singgah hingga menemukan muaranya.',
                    accentColor: const Color(0xFF63A0BF),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==========================================
              // SARAN CARD (tanpa badge)
              // ==========================================
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _cardEntranceController,
                        curve: const Interval(
                          0.35,
                          0.95,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _cardEntranceController,
                    curve: const Interval(0.35, 0.95, curve: Curves.easeOut),
                  ),
                  child: _buildFeedbackCard(
                    title: 'Saran',
                    tagline: 'Harapan Hangat untuk Pembelajaran Mendatang',
                    content: 'Semoga di masa mendatang, racikan "es teh" dalam mata kuliah ini dapat ditakar kembali porsi esnya. Agar kehangatan dan kenikmatan dari proses pembelajaran itu sendiri dapat senantiasa diresapi, tanpa perlu menghentikan detak kreativitas mahasiswa akibat kejutan freeze mendadak di penghujung tenggat waktu.',
                    accentColor: MirroraTheme.dustyRose,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard({
    required String title,
    required String tagline,
    required String content,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MirroraTheme.blushPink),
        boxShadow: [
          BoxShadow(
            color: MirroraTheme.dustyRose.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: judul + tagline di kiri, ikon kutip di kanan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: MirroraTheme.charcoal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MirroraTheme.warmGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.format_quote_rounded,
                size: 28,
                color: accentColor.withValues(alpha: 0.35),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Divider halus
          Container(
            height: 1,
            color: MirroraTheme.blushPink.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),

          // Konten Tulisan
          Text(
            content,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.68,
              color: Color(0xFF3C3537),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// CUSTOM ANIMATED ES TEH CUP WIDGET
class _AnimatedEsTehCup extends StatelessWidget {
  const _AnimatedEsTehCup({required this.floatProgress});

  final double floatProgress;

  @override
  Widget build(BuildContext context) {
    // floatProgress: 0.0 -> 1.0 -> 0.0 (mengayun bolak balik)
    final double bobOffset1 = math.sin(floatProgress * math.pi) * 4.0;
    final double bobOffset2 = math.cos(floatProgress * math.pi) * 3.5;
    final double bobOffset3 = math.sin((floatProgress + 0.5) * math.pi) * 3.0;

    return SizedBox(
      width: 150,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Efek uap dingin / bintang beku melayang di sekitar gelas
          Positioned(
            top: 10 + bobOffset1,
            left: 12,
            child: const Text('❄️', style: TextStyle(fontSize: 16)),
          ),
          Positioned(
            top: 24 + bobOffset2,
            right: 14,
            child: const Text('✨', style: TextStyle(fontSize: 14)),
          ),
          Positioned(
            bottom: 40 + bobOffset3,
            right: 8,
            child: const Text('🧊', style: TextStyle(fontSize: 13)),
          ),

          // SEDOTAN (STRAW)
          Positioned(
            top: 0 + bobOffset1 * 0.4,
            right: 48,
            child: Transform.rotate(
              angle: 0.28,
              child: Container(
                width: 10,
                height: 80,
                decoration: BoxDecoration(
                  color: MirroraTheme.dustyRose,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(
                    5,
                    (i) => Container(
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      color: i.isEven ? MirroraTheme.white : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // LEMON SLICE ON RIM
          Positioned(
            top: 40,
            left: 20,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD152),
                  border: Border.all(color: const Color(0xFFF39C12), width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFF9E6),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 10,
                      color: Color(0xFFFFF9E6),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // GELAS UTAMA (GLASS BODY)
          Positioned(
            bottom: 12,
            child: Container(
              width: 96,
              height: 124,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(34),
                ),
                border: Border.all(
                  color: const Color(0xFF70A1FF).withValues(alpha: 0.5),
                  width: 2.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.8),
                    const Color(0xFFE3F2FD).withValues(alpha: 0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE58E26).withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                  bottom: Radius.circular(30),
                ),
                child: Stack(
                  children: [
                    // AIR ES TEH (TEA LIQUID)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 104,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF39C12), // Teh warna amber terang
                              Color(0xFFD35400), // Teh pekat
                              Color(0xFFA04000), // Bagian bawah gelap
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ES BATU 1 (FLOATING ICE CUBE 1)
                    Positioned(
                      top: 26 + bobOffset1,
                      left: 14,
                      child: _buildIceCube(24, 24, -0.15),
                    ),

                    // ES BATU 2 (FLOATING ICE CUBE 2)
                    Positioned(
                      top: 32 + bobOffset2,
                      right: 14,
                      child: _buildIceCube(26, 26, 0.22),
                    ),

                    // ES BATU 3 (FLOATING ICE CUBE 3)
                    Positioned(
                      top: 58 + bobOffset3,
                      left: 32,
                      child: _buildIceCube(22, 22, 0.08),
                    ),

                    // KAWAII SMILING FACE (WAJAH LUCU DI GELAS)
                    Positioned(
                      bottom: 22,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Pipi kiri
                          Container(
                            width: 6,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7675)
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Mata kiri
                          const Text(
                            'ᵔ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2C1609),
                              height: 1,
                            ),
                          ),
                          // Senyum
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '‿',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C1609),
                                height: 1,
                              ),
                            ),
                          ),
                          // Mata kanan
                          const Text(
                            'ᵔ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2C1609),
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Pipi kanan
                          Container(
                            width: 6,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7675)
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // KILAUAN KACA (GLASS HIGHLIGHT)
                    Positioned(
                      top: 8,
                      left: 6,
                      child: Container(
                        width: 5,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // BULIR AIR DINGIN (CONDENSATION DROPLETS)
                    Positioned(
                      top: 48,
                      right: 7,
                      child: Container(
                        width: 3.5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 66,
                      right: 9,
                      child: Container(
                        width: 3,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIceCube(double width, double height, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: width * 0.45,
            height: height * 0.45,
            decoration: BoxDecoration(
              color: const Color(0xFFDFF9FB).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
