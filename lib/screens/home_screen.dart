import 'package:flutter/material.dart';

import '../theme/mirrora_theme.dart';

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
            _buildWeatherCard(),
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

  // --------------------------------------------------------------- WEATHER
  // Data masih dummy, nanti diganti hasil Open-Meteo.
  Widget _buildWeatherCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: MirroraTheme.blushPink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wb_sunny_rounded,
            size: 64,
            color: MirroraTheme.softGold,
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jakarta',
                  style: TextStyle(fontSize: 13, color: MirroraTheme.warmGray),
                ),
                SizedBox(height: 2),
                Text(
                  '28°C',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cerah',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MirroraTheme.charcoal,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: MirroraTheme.dustyRose,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
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
            onTap: () => _comingSoon('Shake to Pick'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessCard(
            icon: Icons.sports_esports_outlined,
            label: 'Mini Game',
            onTap: () => _comingSoon('Mini Game'),
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

// ================================================================ WIDGETS

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
