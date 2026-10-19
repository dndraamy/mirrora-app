import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;

import '../services/auth_service.dart';
import '../theme/mirrora_theme.dart';
import '../widgets/forgot_password_sheet.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;

  // Real-time strength states
  bool _hasMinLength = false;
  bool _hasUpperAndLower = false;
  bool _hasDigit = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_evaluatePasswordStrength);
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _evaluatePasswordStrength() {
    final text = _newPasswordController.text;
    setState(() {
      _hasMinLength = text.length >= 8;
      _hasUpperAndLower = RegExp(r'[a-z]').hasMatch(text) && RegExp(r'[A-Z]').hasMatch(text);
      _hasDigit = RegExp(r'[0-9]').hasMatch(text);
      _hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(text);
    });
  }

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUpperAndLower) score++;
    if (_hasDigit) score++;
    if (_hasSpecial) score++;
    return score;
  }

  String get _strengthLabel {
    if (_newPasswordController.text.isEmpty) return 'Belum diisi';
    switch (_strengthScore) {
      case 1:
        return 'Lemah';
      case 2:
        return 'Cukup';
      case 3:
        return 'Kuat';
      case 4:
        return 'Sangat Kuat';
      default:
        return 'Sangat Lemah';
    }
  }

  Color get _strengthColor {
    if (_newPasswordController.text.isEmpty) return MirroraTheme.warmGray;
    switch (_strengthScore) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orange;
      case 3:
        return MirroraTheme.softGold;
      case 4:
        return MirroraTheme.success;
      default:
        return Colors.redAccent;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFF8B2B3E) : MirroraTheme.charcoal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }

  Future<void> _submitChangePassword() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      _showMessage('Harap lengkapi dan periksa kembali data kata sandi.', isError: true);
      return;
    }

    if (_strengthScore < 2) {
      _showMessage('Kata sandi baru terlalu lemah. Harap penuhi kriteria keamanan.', isError: true);
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (currentPassword == newPassword) {
      _showMessage('Kata sandi baru tidak boleh sama dengan kata sandi saat ini.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseUser = sp.Supabase.instance.client.auth.currentUser;

      if (supabaseUser != null && supabaseUser.email != null) {
        final email = supabaseUser.email!;

        // 1. Verifikasi kredensial lama dengan re-authenticating ke Supabase
        try {
          await sp.Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: currentPassword,
          );
        } on sp.AuthException {
          throw 'Kata sandi saat ini salah. Silakan coba lagi.';
        }

        // 2. Update password terenkripsi via Supabase Auth
        await sp.Supabase.instance.client.auth.updateUser(
          sp.UserAttributes(password: newPassword),
        );

        // 3. Sinkronkan juga hash lokal BCrypt di Hive jika ada box pengguna
        if (Hive.isBoxOpen('userBox')) {
          final box = Hive.box('userBox');
          if (box.containsKey(email.toLowerCase())) {
            final localData = Map<String, dynamic>.from(box.get(email.toLowerCase()) as Map);
            localData['passwordHash'] = BCrypt.hashpw(newPassword, BCrypt.gensalt());
            await box.put(email.toLowerCase(), localData);
          }
        }
      } else {
        // Fallback untuk akun offline/lokal Hive via AuthService
        final authService = AuthService();
        await authService.changePassword(
          oldPassword: currentPassword,
          newPassword: newPassword,
        );
      }

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      _showMessage(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: MirroraTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: MirroraTheme.success,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Kata Sandi Berhasil Diubah! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Kata sandi akun Mirrora kamu telah terenkripsi dan diperbarui dengan aman. Gunakan kata sandi baru untuk login berikutnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: MirroraTheme.warmGray,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Back to settings
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MirroraTheme.dustyRose,
                  foregroundColor: MirroraTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmMatching = _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _newPasswordController.text;

    return Scaffold(
      backgroundColor: MirroraTheme.white,
      appBar: AppBar(
        backgroundColor: MirroraTheme.white,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: MirroraTheme.cream,
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
          'Ubah Kata Sandi',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Security Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MirroraTheme.cream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MirroraTheme.blushPink),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: MirroraTheme.blushPink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: MirroraTheme.dustyRose,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enkripsi Kriptografis Aman',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: MirroraTheme.charcoal,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Kata sandi Anda diproteksi dengan hashing berstandar industri sehingga aman terlindungi.',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: MirroraTheme.charcoal.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 1. KATA SANDI SAAT INI
                const Text(
                  'Kata Sandi Saat Ini',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    hintText: 'Masukkan kata sandi lama kamu',
                    prefixIcon: const Icon(Icons.lock_clock_outlined, color: MirroraTheme.dustyRose, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: MirroraTheme.warmGray,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Kata sandi saat ini wajib diisi';
                    }
                    return null;
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final email = sp.Supabase.instance.client.auth.currentUser?.email;
                      ForgotPasswordSheet.show(context, initialEmail: email);
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                    child: const Text(
                      'Lupa kata sandi saat ini?',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: MirroraTheme.dustyRose,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 2. KATA SANDI BARU
                const Text(
                  'Kata Sandi Baru',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    hintText: 'Minimal 8 karakter',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: MirroraTheme.dustyRose, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: MirroraTheme.warmGray,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi baru wajib diisi';
                    }
                    if (val.length < 8) {
                      return 'Kata sandi minimal 8 karakter';
                    }
                    return null;
                  },
                ),

                // Strength Indicator Bar & Label
                if (_newPasswordController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _strengthScore / 4.0,
                            backgroundColor: MirroraTheme.blushPink,
                            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _strengthLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _strengthColor,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Criteria Checklist Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: MirroraTheme.cream.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MirroraTheme.blushPink),
                  ),
                  child: Column(
                    children: [
                      _buildCriteriaRow('Minimal 8 karakter', _hasMinLength),
                      const SizedBox(height: 6),
                      _buildCriteriaRow('Kombinasi huruf besar (A-Z) & kecil (a-z)', _hasUpperAndLower),
                      const SizedBox(height: 6),
                      _buildCriteriaRow('Mengandung angka (0-9)', _hasDigit),
                      const SizedBox(height: 6),
                      _buildCriteriaRow('Simbol khusus (opsional, disarankan)', _hasSpecial),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. KONFIRMASI KATA SANDI BARU
                const Text(
                  'Konfirmasi Kata Sandi Baru',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Ulangi kata sandi baru',
                    prefixIcon: const Icon(Icons.lock_rounded, color: MirroraTheme.dustyRose, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_confirmPasswordController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              isConfirmMatching ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: isConfirmMatching ? MirroraTheme.success : Colors.redAccent,
                              size: 18,
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: MirroraTheme.warmGray,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ],
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Konfirmasi kata sandi wajib diisi';
                    }
                    if (val != _newPasswordController.text) {
                      return 'Konfirmasi kata sandi tidak cocok';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MirroraTheme.dustyRose,
                      foregroundColor: MirroraTheme.white,
                      elevation: 2,
                      shadowColor: MirroraTheme.dustyRose.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: MirroraTheme.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_reset_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Simpan Kata Sandi Baru',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaRow(String title, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isMet ? MirroraTheme.success : MirroraTheme.warmGray.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              color: isMet ? MirroraTheme.charcoal : MirroraTheme.warmGray,
            ),
          ),
        ),
      ],
    );
  }
}
