import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/mirrora_theme.dart';
import 'bubble_pop_screen.dart';
import 'shake_to_pick_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.userName = 'Sarah'});

  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _RoutineItem {
  _RoutineItem(this.title, {this.done = false});

  final String title;
  bool done;
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_RoutineItem> _routines = [
    _RoutineItem('Morning Skincare', done: true),
    _RoutineItem('Minum Air Putih', done: true),
    _RoutineItem('Hair Care'),
    _RoutineItem('Night Skincare'),
  ];

  int get _doneCount => _routines.where((r) => r.done).length;

  // ── Lifecycle ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Tampilkan daily prompt setelah frame pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDailyPrompt());
  }

  /// Tampilkan dialog Shake to Pick sekali per hari (per akun).
  Future<void> _maybeShowDailyPrompt() async {
    if (!mounted) return;
    final box = Hive.box('settingsBox');
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final promptKey = 'shake_prompt_last_date_$uid';
    final lastShown = box.get(promptKey, defaultValue: '') as String;

    if (lastShown == dateKey) return; // sudah ditampilkan hari ini untuk akun ini

    await box.put(promptKey, dateKey);
    if (!mounted) return;

    // Delay kecil agar UI home sudah fully visible sebelum popup muncul
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ShakeToPickPromptDialog(),
    );
  }

  void _toggleRoutine(_RoutineItem item) {
    setState(() => item.done = !item.done);
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature segera hadir')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const _ClockCard(),
            const SizedBox(height: 26),
            _buildRoutineCard(),
            const SizedBox(height: 26),
            const _SectionTitle('Quick Access'),
            const SizedBox(height: 12),
            _buildQuickAccess(),
            const SizedBox(height: 16),
            _buildBeautyPick(),
            const SizedBox(height: 16),
            _buildInfoCards(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- HEADER
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai, ${widget.userName}! 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Semoga harimu selalu bersinar',
                style: TextStyle(fontSize: 13, color: MirroraTheme.warmGray),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _comingSoon('Notifikasi'),
          tooltip: 'Notifikasi',
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: MirroraTheme.charcoal,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- ROUTINE
  Widget _buildRoutineCard() {
    final total = _routines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle('Rutinitas Hari Ini'),
            Text(
              '$_doneCount/$total selesai',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MirroraTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MirroraTheme.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MirroraTheme.blushPink),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : _doneCount / total,
                    minHeight: 6,
                    backgroundColor: MirroraTheme.blushPink,
                    valueColor: const AlwaysStoppedAnimation(
                      MirroraTheme.dustyRose,
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < _routines.length; i++) ...[
                _buildRoutineTile(_routines[i]),
                if (i != _routines.length - 1)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: MirroraTheme.blushPink,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineTile(_RoutineItem item) {
    return InkWell(
      onTap: () => _toggleRoutine(item),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: item.done ? MirroraTheme.success : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.done
                      ? MirroraTheme.success
                      : MirroraTheme.warmGray.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: item.done
                  ? const Icon(Icons.check, size: 16, color: MirroraTheme.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: item.done
                      ? MirroraTheme.warmGray
                      : MirroraTheme.charcoal,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- QUICK ACCESS
  Widget _buildQuickAccess() {
    return Row(
      children: [
        Expanded(
          child: _QuickAccessCard(
            icon: Icons.vibration_rounded,
            label: 'Shake to Pick',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShakeToPickScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessCard(
            icon: Icons.sports_esports_outlined,
            label: 'Mini Game',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BubblePopScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessCard(
            icon: Icons.favorite_border_rounded,
            label: 'Produk Favorit',
            onTap: () => _comingSoon('Produk Favorit'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ BEAUTY PICK
  Widget _buildBeautyPick() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MirroraTheme.blushPink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beauty Pick untukmu',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Produk sesuai dengan jenis kulitmu',
                  style: TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _comingSoon('Rekomendasi produk'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Lihat Rekomendasi'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MirroraTheme.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              size: 34,
              color: MirroraTheme.dustyRose,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- INFO CARDS
  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.emoji_events_outlined,
            iconColor: MirroraTheme.softGold,
            title: 'Achievement',
            subtitle: 'Belum ada yang terbuka',
            onTap: () => _comingSoon('Achievement'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            icon: Icons.storefront_outlined,
            iconColor: MirroraTheme.dustyRose,
            title: 'Toko Terdekat',
            subtitle: 'Cari toko kosmetik',
            onTap: () => _comingSoon('Toko Terdekat'),
          ),
        ),
      ],
    );
  }
}

// ================================================================ CLOCK CARD

class _ClockCard extends StatefulWidget {
  const _ClockCard();

  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard>
    with SingleTickerProviderStateMixin {
  late DateTime _now;
  StreamSubscription<int>? _tickSub;

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _pulseAnim = CurvedAnimation(
    parent: _pulseCtrl,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _tickSub = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((
      _,
    ) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  static String _zoneLabel(DateTime dt) {
    final offset = dt.timeZoneOffset;
    if (offset == const Duration(hours: 7)) return 'WIB';
    if (offset == const Duration(hours: 8)) return 'WITA';
    if (offset == const Duration(hours: 9)) return 'WIT';
    return dt.timeZoneName;
  }

  static String _dayName(int weekday) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return days[weekday - 1];
  }

  static String _monthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  String get _hh => _now.hour.toString().padLeft(2, '0');
  String get _mm => _now.minute.toString().padLeft(2, '0');
  String get _ss => _now.second.toString().padLeft(2, '0');
  String get _dateLabel =>
      '${_dayName(_now.weekday)}, ${_now.day} ${_monthName(_now.month)} ${_now.year}';
  String get _zone => _zoneLabel(_now);

  void _openConverter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimeConverterSheet(baseTime: _now),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFAA7080), Color(0xFFC98C9C), Color(0xFFEFBEC9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: MirroraTheme.dustyRose.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekoratif — lingkaran transparan
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MirroraTheme.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            right: 35,
            bottom: -32,
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MirroraTheme.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          // Konten utama
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─ Kiri: tampilan jam ─
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge zona waktu
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: MirroraTheme.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: MirroraTheme.white.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: MirroraTheme.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _zone,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MirroraTheme.white,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // HH : MM + detik
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _hh,
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: MirroraTheme.white,
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                          FadeTransition(
                            opacity: _pulseAnim,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 1),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w300,
                                  color: MirroraTheme.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _mm,
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: MirroraTheme.white,
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Detik kecil
                          Text(
                            _ss,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: MirroraTheme.white.withValues(alpha: 0.72),
                              height: 1.0,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tanggal
                      Text(
                        _dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: MirroraTheme.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─ Kanan: tombol konversi ─
                GestureDetector(
                  onTap: _openConverter,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: MirroraTheme.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MirroraTheme.white.withValues(alpha: 0.40),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.public_rounded,
                          color: MirroraTheme.white,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zona',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: MirroraTheme.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================= CONVERTER SHEET

/// Data class untuk satu zona waktu.
class _ZoneInfo {
  const _ZoneInfo(this.code, this.label, this.utcOffset, this.icon);

  final String code;
  final String label;
  final int utcOffset;
  final IconData icon;
}

class _TimeConverterSheet extends StatefulWidget {
  const _TimeConverterSheet({required this.baseTime});

  final DateTime baseTime;

  @override
  State<_TimeConverterSheet> createState() => _TimeConverterSheetState();
}

class _TimeConverterSheetState extends State<_TimeConverterSheet>
    with SingleTickerProviderStateMixin {
  late DateTime _now;
  StreamSubscription<int>? _tickSub;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeOut,
  );

  static const _zones = <_ZoneInfo>[
    _ZoneInfo('WIB', 'Waktu Indonesia Barat', 7, Icons.location_on_outlined),
    _ZoneInfo('WITA', 'Waktu Indonesia Tengah', 8, Icons.location_on_outlined),
    _ZoneInfo('WIT', 'Waktu Indonesia Timur', 9, Icons.location_on_outlined),
    _ZoneInfo('London', 'United Kingdom (UTC+1)', 1, Icons.flight_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _now = widget.baseTime;
    _tickSub = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((
      _,
    ) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  DateTime _toZone(int utcOffsetHours) =>
      _now.toUtc().add(Duration(hours: utcOffsetHours));

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  String _currentZoneCode() {
    final offset = _now.timeZoneOffset;
    if (offset == const Duration(hours: 7)) return 'WIB';
    if (offset == const Duration(hours: 8)) return 'WITA';
    if (offset == const Duration(hours: 9)) return 'WIT';
    return _now.timeZoneName;
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = _currentZoneCode();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color: MirroraTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 14),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MirroraTheme.blushPink,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        color: MirroraTheme.dustyRose,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konversi Zona Waktu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MirroraTheme.charcoal,
                            ),
                          ),
                          Text(
                            'Real-time berdasarkan perangkat kamu',
                            style: TextStyle(
                              fontSize: 11,
                              color: MirroraTheme.warmGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: MirroraTheme.warmGray,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Divider(color: MirroraTheme.blushPink, height: 1),
              ),
              const SizedBox(height: 14),

              // Daftar zona
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: List.generate(_zones.length, (i) {
                    final z = _zones[i];
                    final isActive = z.code == currentCode;
                    return _ZoneTile(
                      zone: z,
                      time: _fmt(_toZone(z.utcOffset)),
                      isActive: isActive,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tile satu zona ────────────────────────────────────────────────────────

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.zone,
    required this.time,
    required this.isActive,
  });

  final _ZoneInfo zone;
  final String time;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isActive ? MirroraTheme.dustyRose : MirroraTheme.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? MirroraTheme.dustyRose : MirroraTheme.blushPink,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: MirroraTheme.dustyRose.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Icon zona
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? MirroraTheme.white.withValues(alpha: 0.20)
                  : MirroraTheme.blushPink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              zone.icon,
              size: 18,
              color: isActive ? MirroraTheme.white : MirroraTheme.dustyRose,
            ),
          ),
          const SizedBox(width: 14),

          // Nama zona
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      zone.code,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? MirroraTheme.white
                            : MirroraTheme.charcoal,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MirroraTheme.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Lokasimu',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  zone.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? MirroraTheme.white.withValues(alpha: 0.78)
                        : MirroraTheme.warmGray,
                  ),
                ),
              ],
            ),
          ),

          // Jam real-time
          Text(
            time,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: isActive ? MirroraTheme.white : MirroraTheme.charcoal,
              letterSpacing: 0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================ SHARED WIDGETS

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: MirroraTheme.charcoal,
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MirroraTheme.blushPink,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, size: 26, color: MirroraTheme.dustyRose),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MirroraTheme.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MirroraTheme.blushPink),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: MirroraTheme.warmGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}