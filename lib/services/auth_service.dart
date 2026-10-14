import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Register & login memakai Hive (userBox) + bcrypt.
/// Session (email user yang sedang login) disimpan di flutter_secure_storage.
class AuthService {
  static const String _boxName = 'userBox';
  static const String _sessionKey = 'mirrora_session_email';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Panggil sekali di main() sebelum runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  /// Daftar akun baru, lalu otomatis login. Melempar [AuthException] jika gagal.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final emailKey = email.trim().toLowerCase();
    final name = username.trim();

    if (_box.containsKey(emailKey)) {
      throw AuthException('Email sudah terdaftar');
    }
    if (_findByUsername(name) != null) {
      throw AuthException('Username sudah dipakai');
    }

    final user = <String, dynamic>{
      'username': name,
      'email': emailKey,
      'passwordHash': BCrypt.hashpw(password, BCrypt.gensalt()),
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _box.put(emailKey, user);
    await _storage.write(key: _sessionKey, value: emailKey);
    return user;
  }

  /// [identity] boleh email atau username. Melempar [AuthException] jika gagal.
  Future<Map<String, dynamic>> login({
    required String identity,
    required String password,
  }) async {
    final id = identity.trim();
    final user = _box.containsKey(id.toLowerCase())
        ? _asMap(_box.get(id.toLowerCase()))
        : _findByUsername(id);

    if (user == null) {
      throw AuthException('Akun tidak ditemukan');
    }
    if (!BCrypt.checkpw(password, user['passwordHash'] as String)) {
      throw AuthException('Password salah');
    }

    await _storage.write(key: _sessionKey, value: user['email'] as String);
    return user;
  }

  /// User yang sedang login (null jika belum ada session).
  Future<Map<String, dynamic>?> currentUser() async {
    try {
      final email = await _storage.read(key: _sessionKey);
      if (email == null) return null;
      final data = _box.get(email);
      return data == null ? null : _asMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => _storage.delete(key: _sessionKey);

  Map<String, dynamic>? _findByUsername(String username) {
    final target = username.trim().toLowerCase();
    for (final value in _box.values) {
      final user = _asMap(value);
      if ((user['username'] as String).toLowerCase() == target) return user;
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
}
