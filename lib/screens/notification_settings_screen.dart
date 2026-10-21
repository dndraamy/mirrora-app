import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/notification_service.dart';
import '../theme/mirrora_theme.dart';
import 'daily_routine_screen.dart';

/// Halaman Pengaturan Notifikasi Aplikasi Mirrora
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const String _notifPrefMorningKey = 'notif_pref_morning_enabled';
  static const String _notifPrefNightKey = 'notif_pref_night_enabled';
  static const String _notifPrefGiveawayKey = 'notif_pref_giveaway_enabled';

  final NotificationService _notifService = NotificationService();

  bool _morningNotifEnabled = true;
  bool _nightNotifEnabled = true;
  bool _giveawayNotifEnabled = true;
  bool _systemPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermission();
  }

  void _loadPreferences() {
    try {
      if (Hive.isBoxOpen('settingsBox')) {
        final box = Hive.box('settingsBox');
        _morningNotifEnabled =
            box.get(_notifPrefMorningKey, defaultValue: true) as bool;
        _nightNotifEnabled =
            box.get(_notifPrefNightKey, defaultValue: true) as bool;
        _giveawayNotifEnabled =
            box.get(_notifPrefGiveawayKey, defaultValue: true) as bool;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _systemPermissionGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestPermission() async {
    final granted = await _notifService.requestPermissions();
    if (mounted) {
      setState(() {
        _systemPermissionGranted = granted;
      });
      if (granted) {
        _showMessage('Izin notifikasi berhasil diaktifkan! ✨');
      } else {
        _showMessage(
          'Izin belum diberikan. Aktifkan notifikasi Mirrora di Pengaturan HP kamu.',
        );
      }
    }
  }

  Future<void> _savePref(String key, bool val) async {
    try {
      if (Hive.isBoxOpen('settingsBox')) {
        await Hive.box('settingsBox').put(key, val);
      }
    } catch (_) {}
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: MirroraTheme.charcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: MirroraTheme.charcoal,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan Notifikasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner Izin Sistem
              if (!_systemPermissionGranted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE0B2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_off_outlined,
                          color: Color(0xFFE65100),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Izin Notifikasi Belum Aktif',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100),
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Izinkan notifikasi agar kamu tidak ketinggalan jadwal skincare & pengumuman giveaway.',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                color: MirroraTheme.charcoal,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: _requestPermission,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Aktifkan Izin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Header Ringkasan
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBECEF), Color(0xFFF8E0E6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: MirroraTheme.dustyRose.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🔔', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Alert Mirrora',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: MirroraTheme.charcoal,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Tetap terhubung dengan ritme self-care dan event berhadiah eksklusif.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: MirroraTheme.warmGray,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 1: PENGINGAT RUTINITAS SKINCARE
              const _SectionHeader(
                title: 'Rutinitas Skincare',
                subtitle: 'Notifikasi harian sesuai jam yang kamu tentukan',
              ),
              const SizedBox(height: 10),
              _CardContainer(
                children: [
                  _SwitchTile(
                    icon: Icons.wb_sunny_rounded,
                    iconBg: const Color(0xFFFFF3E0),
                    iconColor: const Color(0xFFE65100),
                    title: 'Rutinitas Pagi (Morning Skincare)',
                    subtitle:
                        'Pengingat bangun tidur & sebelum beraktivitas',
                    value: _morningNotifEnabled,
                    onChanged: (val) {
                      setState(() => _morningNotifEnabled = val);
                      _savePref(_notifPrefMorningKey, val);
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 64,
                    color: MirroraTheme.blushPink,
                  ),
                  _SwitchTile(
                    icon: Icons.nightlight_round,
                    iconBg: const Color(0xFFEDE7F6),
                    iconColor: const Color(0xFF512DA8),
                    title: 'Rutinitas Malam (Night Skincare)',
                    subtitle:
                        'Pengingat relaksasi kulit sebelum tidur malam',
                    value: _nightNotifEnabled,
                    onChanged: (val) {
                      setState(() => _nightNotifEnabled = val);
                      _savePref(_notifPrefNightKey, val);
                    },
                  ),
                  const Divider(
                    height: 1,
                    indent: 64,
                    color: MirroraTheme.blushPink,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        color: MirroraTheme.dustyRose,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Atur Jam Rutinitas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    subtitle: const Text(
                      'Buka jadwal lengkap & sesuaikan alarm',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: MirroraTheme.warmGray,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: MirroraTheme.warmGray,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyRoutineScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // SECTION 2: EVENT & GIVEAWAY
              const _SectionHeader(
                title: 'Event & Giveaway',
                subtitle:
                    'Kabar gembira saat ada undian & pengumuman pemenang',
              ),
              const SizedBox(height: 10),
              _CardContainer(
                children: [
                  _SwitchTile(
                    icon: Icons.celebration_rounded,
                    iconBg: const Color(0xFFFFF9EE),
                    iconColor: const Color(0xFFC5A880),
                    title: 'Info & Hasil Undian Giveaway',
                    subtitle:
                        'Pemberitahuan saat undian dibuka & pengumuman resmi pemenang',
                    value: _giveawayNotifEnabled,
                    onChanged: (val) {
                      setState(() => _giveawayNotifEnabled = val);
                      _savePref(_notifPrefGiveawayKey, val);
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MirroraTheme.cream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: MirroraTheme.blushPink,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                          color: MirroraTheme.dustyRose,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jika kamu terpilih sebagai pemenang undian, kamu akan langsung menerima notifikasi ucapan selamat & petunjuk klaim verifikasi hadiah.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: MirroraTheme.charcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: MirroraTheme.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: MirroraTheme.warmGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MirroraTheme.blushPink),
        boxShadow: [
          BoxShadow(
            color: MirroraTheme.dustyRose.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: MirroraTheme.warmGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: MirroraTheme.dustyRose,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: MirroraTheme.warmGray.withValues(alpha: 0.3),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
