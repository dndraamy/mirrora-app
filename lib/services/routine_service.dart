import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/routine_model.dart';

/// Service terpusat untuk menyimpan dan mengelola Daily Routine (Rutinitas Skincare) pengguna.
/// Tersimpan secara persisten di Hive dan terisolasi per akun Supabase.
class RoutineService extends ChangeNotifier {
  static final RoutineService _instance = RoutineService._internal();
  factory RoutineService() => _instance;

  RoutineService._internal() {
    _initAuthListener();
    _loadFromStorage();
  }

  static const String _boxName = 'settingsBox';
  static const String _keyPrefix = 'mirrora_user_routines_v1_';

  List<DailyRoutine> _routines = [];
  bool _isLoaded = false;
  String _currentStorageKey = '';

  /// Mendengarkan perubahan login/logout Supabase secara real-time
  void _initAuthListener() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final newKey = _getUserStorageKey();
        if (newKey != _currentStorageKey) {
          _loadFromStorage();
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  /// Memastikan data yang ada di RAM adalah milik akun yang sedang aktif
  void _ensureLoadedForCurrentUser() {
    final activeKey = _getUserStorageKey();
    if (!_isLoaded || activeKey != _currentStorageKey) {
      _loadFromStorage();
    }
  }

  /// Daftar rutinitas skincare pengguna saat ini
  List<DailyRoutine> get routines {
    _ensureLoadedForCurrentUser();
    return List.unmodifiable(_routines);
  }

  /// Jumlah rutinitas yang telah diselesaikan hari ini
  int get completedCount {
    _ensureLoadedForCurrentUser();
    return _routines.where((r) => r.isCompleted).length;
  }

  /// Total rutinitas yang ada
  int get totalCount {
    _ensureLoadedForCurrentUser();
    return _routines.length;
  }

  /// Progress penyelesaian hari ini (0.0 – 1.0)
  double get progress {
    if (totalCount == 0) return 0.0;
    return completedCount / totalCount;
  }

  /// Menghasilkan format tanggal hari ini (yyyy-MM-dd)
  static String get _todayDate {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Key penyimpanan unik per akun pengguna Supabase
  String _getUserStorageKey() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return '${_keyPrefix}uid_${user.id}';
      }
      if (user?.email != null && user!.email!.isNotEmpty) {
        return '${_keyPrefix}email_${user.email!.toLowerCase().trim()}';
      }
    } catch (_) {}
    return '${_keyPrefix}guest';
  }

  /// Memuat data rutinitas dari Hive & melakukan auto-reset harian jika tanggal telah berganti
  void _loadFromStorage() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;

      final key = _getUserStorageKey();
      _currentStorageKey = key;
      final dynamic raw = Hive.box(_boxName).get(key);

      List<dynamic> items = [];
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) items = decoded;
        } catch (_) {}
      } else if (raw is List && raw.isNotEmpty) {
        items = raw;
      }

      if (items.isNotEmpty) {
        final List<DailyRoutine> loaded = [];
        final today = _todayDate;

        for (final item in items) {
          try {
            Map<String, dynamic> map;
            if (item is Map) {
              map = Map<String, dynamic>.from(item);
            } else if (item is String) {
              map = Map<String, dynamic>.from(json.decode(item) as Map);
            } else {
              continue;
            }
            final routine = DailyRoutine.fromMap(map);
            final isToday = routine.lastCompletedDate == today;
            loaded.add(routine.copyWith(
              isCompleted: isToday ? routine.isCompleted : false,
            ));
          } catch (_) {}
        }

        _routines = loaded;
        _isLoaded = true;
      } else {
        // Jika belum ada rutinitas yang diinput oleh user, biarkan kosong
        _routines = [];
        _isLoaded = true;
      }
    } catch (e) {
      debugPrint('Error loading routines: $e');
      _routines = [];
      _isLoaded = true;
    }
  }

  /// Menyimpan daftar rutinitas ke Hive (sebagai JSON string agar aman di semua platform & web)
  Future<void> _saveToStorage() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final key = _getUserStorageKey();
      final serialized = _routines.map((r) => r.toMap()).toList();
      final jsonStr = json.encode(serialized);
      await Hive.box(_boxName).put(key, jsonStr);
    } catch (e) {
      debugPrint('Error saving routines: $e');
    }
  }

  /// Muat ulang rutinitas saat berganti akun
  Future<void> reload() async {
    _loadFromStorage();
    notifyListeners();
  }

  /// Toggle status selesai / belum selesai untuk rutinitas tertentu
  Future<void> toggleRoutine(String id) async {
    final index = _routines.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final current = _routines[index];
    final nextState = !current.isCompleted;

    _routines = List<DailyRoutine>.from(_routines);
    _routines[index] = current.copyWith(
      isCompleted: nextState,
      lastCompletedDate: nextState ? _todayDate : null,
    );

    notifyListeners();
    await _saveToStorage();
  }

  /// Menambah rutinitas baru
  Future<void> addRoutine(DailyRoutine routine) async {
    _routines = List<DailyRoutine>.from(_routines);
    _routines.add(routine.copyWith(
      orderIndex: _routines.length,
    ));
    notifyListeners();
    await _saveToStorage();
  }

  /// Memperbarui rutinitas yang sudah ada
  Future<void> updateRoutine(DailyRoutine updated) async {
    final index = _routines.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _routines = List<DailyRoutine>.from(_routines);
      _routines[index] = updated;
      notifyListeners();
      await _saveToStorage();
    }
  }

  /// Menghapus rutinitas berdasarkan ID
  Future<void> deleteRoutine(String id) async {
    _routines = List<DailyRoutine>.from(_routines);
    _routines.removeWhere((r) => r.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  /// Mereset semua checklist rutinitas untuk hari ini
  Future<void> resetAllForToday() async {
    _routines = _routines.map((r) => r.copyWith(
      isCompleted: false,
      lastCompletedDate: null,
    )).toList();
    notifyListeners();
    await _saveToStorage();
  }

  /// Memuat kembali template standar skincare
  Future<void> loadStarterTemplate() async {
    _routines = List<DailyRoutine>.from(DailyRoutine.defaultStarterRoutines());
    notifyListeners();
    await _saveToStorage();
  }

  /// Menghapus semua rutinitas yang ada
  Future<void> clearAllRoutines() async {
    _routines = [];
    notifyListeners();
    await _saveToStorage();
  }

  /// Dipanggil saat user logout agar data in-memory bersih dan tidak terbawa ke akun berikutnya
  void onUserLogout() {
    _currentStorageKey = '';
    _routines = [];
    _isLoaded = false;
    notifyListeners();
  }
}

