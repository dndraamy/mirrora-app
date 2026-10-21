import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/routine_model.dart';

/// Service untuk mengelola notifikasi lokal terjadwal & push instan di perangkat.
/// Mendukung:
/// 1. Pengingat harian rutinitas skincare (Pagi & Malam).
/// 2. Notifikasi Giveaway: Pembukaan Undian, Pengumuman Pemenang, & Khusus Pemenang (Klaim Hadiah).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Channels
  static const String _routineChannelId = 'mirrora_daily_routine_channel';
  static const String _routineChannelName = 'Pengingat Rutinitas Skincare';
  static const String _routineChannelDesc =
      'Notifikasi pengingat harian agar rutinitas skincare tidak terlewat';

  static const String _giveawayChannelId = 'mirrora_giveaway_channel';
  static const String _giveawayChannelName = 'Informasi & Pemenang Giveaway';
  static const String _giveawayChannelDesc =
      'Notifikasi pembukaan giveaway, hasil pengundian, dan hadiah pemenang';

  /// Inisialisasi plugin notifikasi dan zona waktu perangkat
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Inisialisasi basis data zona waktu
      tz.initializeTimeZones();
      _setupLocalTimeZone();

      // 2. Konfigurasi inisialisasi per platform
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // 3. Buat notification channels di Android dengan prioritas tinggi
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          const AndroidNotificationChannel routineChannel = AndroidNotificationChannel(
            _routineChannelId,
            _routineChannelName,
            description: _routineChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          );

          const AndroidNotificationChannel giveawayChannel = AndroidNotificationChannel(
            _giveawayChannelId,
            _giveawayChannelName,
            description: _giveawayChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          );

          await androidPlugin.createNotificationChannel(routineChannel);
          await androidPlugin.createNotificationChannel(giveawayChannel);
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService successfully initialized.');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Menentukan zona waktu lokal pengguna
  void _setupLocalTimeZone() {
    try {
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      if (offsetHours == 7) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } else if (offsetHours == 8) {
        tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
      } else if (offsetHours == 9) {
        tz.setLocalLocation(tz.getLocation('Asia/Jayapura'));
      } else {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      }
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {}
    }
  }

  /// Meminta izin notifikasi kepada pengguna (terutama Android 13+ & iOS)
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  // =========================================================================
  // ROUTINE NOTIFICATIONS (PENGINGAT RUTINITAS SKINCARE)
  // =========================================================================

  int _generateNotificationId(String routineId) {
    return routineId.hashCode.abs() % 2147483647;
  }

  ({int hour, int minute})? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final cleaned = timeStr.trim().replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());
      if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return (hour: hour, minute: minute);
      }
    }
    return null;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Menjadwalkan pengingat harian berulang untuk sebuah rutinitas skincare
  Future<void> scheduleRoutineNotification(DailyRoutine routine) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    final time = _parseTime(routine.time);
    final notificationId = _generateNotificationId(routine.id);

    if (time == null) {
      await cancelRoutineNotification(routine.id);
      return;
    }

    try {
      final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);

      final String timeString =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      final String title = 'Saatnya Rutinitas Skincare ${routine.category}! ✨';
      final String body = routine.note != null && routine.note!.trim().isNotEmpty
          ? 'Waktunya ${routine.title} ($timeString): ${routine.note}'
          : 'Waktunya ${routine.title} ($timeString). Jangan sampai terlewat ya!';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _routineChannelId,
        _routineChannelName,
        channelDescription: _routineChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFFC56B84),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'routine_${routine.id}',
      );

      debugPrint(
        'Scheduled notification for "${routine.title}" at $timeString daily (ID: $notificationId, Next: $scheduledDate)',
      );
    } catch (e) {
      debugPrint('Error scheduling routine notification: $e');
    }
  }

  Future<void> cancelRoutineNotification(String routineId) async {
    if (kIsWeb) return;
    try {
      final notificationId = _generateNotificationId(routineId);
      await _notificationsPlugin.cancel(id: notificationId);
      debugPrint('Cancelled notification ID: $notificationId');
    } catch (e) {
      debugPrint('Error cancelling routine notification: $e');
    }
  }

  Future<void> syncAllRoutineNotifications(List<DailyRoutine> routines) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    for (final routine in routines) {
      if (routine.time != null && routine.time!.trim().isNotEmpty) {
        await scheduleRoutineNotification(routine);
      } else {
        await cancelRoutineNotification(routine.id);
      }
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('All notifications cancelled.');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  // =========================================================================
  // GIVEAWAY NOTIFICATIONS (NOTIFIKASI UNDIAN & PEMENANG)
  // =========================================================================

  /// Notifikasi saat Admin Mengaktifkan Undian (Status = Open)
  Future<void> showGiveawayOpenedNotification({
    required String title,
    required String prize,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _giveawayChannelId,
      _giveawayChannelName,
      channelDescription: _giveawayChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFFC56B84),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: 70001,
      title: '🎉 $title Telah Dibuka!',
      body: 'Hadiah Spesial: $prize! Kumpulkan tiket undian via Shake to Pick sekarang juga!',
      notificationDetails: details,
      payload: 'giveaway_open',
    );
  }

  /// Notifikasi Publik saat Undian Sudah Selesai Diundi
  Future<void> showGiveawayDrawnNotification({
    required String title,
    required String winnerName,
    required String ticketNumber,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _giveawayChannelId,
      _giveawayChannelName,
      channelDescription: _giveawayChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFFC56B84),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: 70002,
      title: '🏆 Pemenang Giveaway Telah Diundi!',
      body: 'Selamat kepada $winnerName ($ticketNumber) atas kemenangannya! Hasil sah terkunci di blockchain lokal.',
      notificationDetails: details,
      payload: 'giveaway_drawn',
    );
  }

  /// Notifikasi Khusus Untuk User yang Memenangkan Undian
  Future<void> showWinnerPersonalNotification({
    required String prize,
    required String ticketNumber,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _giveawayChannelId,
      _giveawayChannelName,
      channelDescription: _giveawayChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFFC56B84),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: 70003,
      title: '👑 SELAMAT! KAMU MEMENANGKAN GIVEAWAY!',
      body: 'Tiketmu $ticketNumber terpilih sebagai pemenang $prize! Buka Mirrora dan isi data dirimu untuk verifikasi pengiriman hadiah.',
      notificationDetails: details,
      payload: 'giveaway_winner_claim',
    );
  }

  /// Notifikasi tes langsung
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _routineChannelId,
      _routineChannelName,
      channelDescription: _routineChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFFC56B84),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: 99999,
      title: 'Pengingat Skincare Mirrora Aktif! ✨',
      body: 'Notifikasi harian dan informasi giveaway akan otomatis muncul di perangkat kamu.',
      notificationDetails: details,
    );
  }
}
