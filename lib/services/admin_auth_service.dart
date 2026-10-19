import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

import '../screens/admin_giveaway_screen.dart';
import '../theme/mirrora_theme.dart';

/// Layanan Keamanan untuk Portal Admin / Owner Mirrora
/// Fitur:
/// 1. Autentikasi Biometrik (Sidik Jari / Face Unlock perangkat)
/// 2. Master Key dengan Kriptografi Hash SHA-256 + Salt (Dapat diganti oleh Owner)
/// 3. Mode Stealth: Opsi sembunyikan tombol dari menu publik
class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _boxName = 'settingsBox';
  static const String _customPasswordHashKey = 'admin_master_password_hash';
  static const String _customPasswordSaltKey = 'admin_master_password_salt';
  static const String _hideTileKey = 'admin_stealth_mode_hidden';

  // Default Master Key jika belum diganti oleh Owner
  static const String defaultMasterKey = 'Owner#Mirrora2026';
  static const String _defaultSalt = 'mirrora_blockchain_secure_salt_99';

  /// Cek apakah mode stealth aktif (sembunyikan tombol dari settings)
  bool isStealthMode() {
    final box = Hive.box(_boxName);
    return box.get(_hideTileKey, defaultValue: false) as bool;
  }

  /// Ubah pengaturan mode stealth
  Future<void> setStealthMode(bool hide) async {
    final box = Hive.box(_boxName);
    await box.put(_hideTileKey, hide);
  }

  /// Hash password dengan salt
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  /// Validasi Master Key yang dimasukkan pengguna
  bool verifyMasterKey(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    final box = Hive.box(_boxName);
    final storedHash = box.get(_customPasswordHashKey) as String?;
    final storedSalt = box.get(_customPasswordSaltKey) as String?;

    if (storedHash != null && storedSalt != null) {
      return _hashPassword(trimmed, storedSalt) == storedHash;
    }

    // Default master key bawaan
    final defaultHash = _hashPassword(defaultMasterKey, _defaultSalt);
    return _hashPassword(trimmed, _defaultSalt) == defaultHash;
  }

  /// Mengubah Master Key oleh Owner
  Future<void> changeMasterKey(String newKey) async {
    final trimmed = newKey.trim();
    if (trimmed.length < 6) {
      throw Exception('Master Key minimal 6 karakter!');
    }
    final salt = 'salt_${DateTime.now().millisecondsSinceEpoch}_mirrora';
    final hash = _hashPassword(trimmed, salt);

    final box = Hive.box(_boxName);
    await box.put(_customPasswordHashKey, hash);
    await box.put(_customPasswordSaltKey, salt);
  }

  /// Cek dukungan hardware biometrik di perangkat
  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Menjalankan verifikasi biometrik
  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah Owner untuk akses Admin Portal',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Alur Keamanan: Biometrik -> Master Passphrase
  Future<void> authenticateAndOpenPortal(BuildContext context) async {
    // 1. Cek apakah biometrik tersedia. Jika ya, coba jalankan terlebih dahulu
    final hasBiometrics = await canUseBiometrics();
    if (!context.mounted) return;

    if (hasBiometrics) {
      final biometricSuccess = await authenticateBiometric();
      if (!context.mounted) return;

      if (biometricSuccess) {
        _openScreen(context);
        return;
      }
    }

    // 2. Jika biometrik tidak tersedia atau dibatalkan, tampilkan dialog Master Passphrase
    if (!context.mounted) return;
    _showMasterKeyDialog(context);
  }

  void _openScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminGiveawayScreen()),
    );
  }

  /// Dialog Masukkan Master Passphrase Owner
  void _showMasterKeyDialog(BuildContext context) {
    final keyController = TextEditingController();
    bool obscure = true;
    String? errorMessage;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: MirroraTheme.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: MirroraTheme.blushPink),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: MirroraTheme.dustyRose.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.shield_rounded, color: MirroraTheme.dustyRose, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Autentikasi Owner',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: MirroraTheme.charcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan Master Passphrase Owner untuk membuka pengelolaan undian blockchain.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: MirroraTheme.warmGray,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: keyController,
                    obscureText: obscure,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: MirroraTheme.charcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Master Passphrase (default: Owner#Mirrora2026)',
                      hintStyle: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                      filled: true,
                      fillColor: MirroraTheme.cream,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: errorMessage != null ? Colors.redAccent : Colors.transparent,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: errorMessage != null ? Colors.redAccent : Colors.transparent,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: errorMessage != null ? Colors.redAccent : MirroraTheme.dustyRose,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18,
                          color: MirroraTheme.warmGray,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(fontSize: 11.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final input = keyController.text.trim();
                    final isValid = verifyMasterKey(input);

                    if (isValid) {
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) _openScreen(context);
                    } else {
                      setState(() {
                        errorMessage = 'Passphrase salah, silakan coba lagi.';
                        keyController.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MirroraTheme.dustyRose,
                    foregroundColor: MirroraTheme.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
