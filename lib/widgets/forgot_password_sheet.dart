import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;

import '../screens/reset_password_screen.dart';
import '../theme/mirrora_theme.dart';

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  static Future<void> show(BuildContext context, {String? initialEmail}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForgotPasswordSheet(initialEmail: initialEmail),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isVerifyingOtp = false;
  bool _emailSent = false;
  bool _showOtpInput = false;
  String _targetEmail = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? const Color(0xFF8B2B3E) : MirroraTheme.charcoal,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Masukkan alamat email yang valid.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // PENTING: redirectTo diatur ke mirrora://login-callback/
      // agar browser langsung membuka aplikasi Mirrora via deep link,
      // BUKAN fallback ke http://localhost:3000!
      await sp.Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'mirrora://login-callback/',
      );

      if (!mounted) return;
      setState(() {
        _emailSent = true;
        _targetEmail = email;
      });
    } on sp.AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Gagal mengirim email reset. Periksa koneksi internet Anda.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpCode() async {
    final token = _otpController.text.trim();
    if (token.length < 6) {
      _showMessage('Masukkan 6 digit kode pemulihan dari email.', isError: true);
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      await sp.Supabase.instance.client.auth.verifyOTP(
        email: _targetEmail,
        token: token,
        type: sp.OtpType.recovery,
      );

      if (!mounted) return;
      Navigator.pop(context); // Tutup bottom sheet
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    } on sp.AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Kode verifikasi tidak valid atau telah kedaluwarsa.', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: MirroraTheme.blushPink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              if (!_emailSent) _buildInputView() else _buildSentView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: MirroraTheme.dustyRose,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lupa Kata Sandi?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kami akan mengirim tautan pemulihan ke email Anda',
                    style: TextStyle(
                      fontSize: 12,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Email Akun',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'nama@email.com',
            prefixIcon: Icon(
              Icons.email_outlined,
              color: MirroraTheme.dustyRose,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MirroraTheme.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MirroraTheme.blushPink),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: MirroraTheme.dustyRose,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tautan pemulihan akan langsung membuka aplikasi Mirrora secara aman.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: MirroraTheme.warmGray,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: MirroraTheme.dustyRose,
              foregroundColor: MirroraTheme.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: MirroraTheme.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Kirim Tautan Reset',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MirroraTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: MirroraTheme.success,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Tautan Pemulihan Terkirim! ✉️',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: MirroraTheme.warmGray,
            ),
            children: [
              const TextSpan(text: 'Kami telah mengirimkan tautan reset ke:\n'),
              TextSpan(
                text: _targetEmail,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const TextSpan(
                text:
                    '\n\nBuka email kamu dan klik tautan tersebut. Aplikasi Mirrora akan otomatis terbuka untuk mengganti kata sandi.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Accordion untuk input kode OTP alternatif jika browser bermasalah
        InkWell(
          onTap: () => setState(() => _showOtpInput = !_showOtpInput),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showOtpInput
                      ? 'Sembunyikan Masukkan Kode'
                      : 'Punya Kode 6-Digit dari Email? Masukkan di sini',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MirroraTheme.dustyRose,
                  ),
                ),
                Icon(
                  _showOtpInput
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: MirroraTheme.dustyRose,
                ),
              ],
            ),
          ),
        ),

        if (_showOtpInput) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
            decoration: const InputDecoration(
              hintText: '123456',
              counterText: '',
              hintStyle: TextStyle(
                letterSpacing: 6,
                color: MirroraTheme.warmGray,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isVerifyingOtp ? null : _verifyOtpCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: MirroraTheme.dustyRose,
                foregroundColor: MirroraTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: _isVerifyingOtp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: MirroraTheme.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Verifikasi Kode & Ganti Password',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: MirroraTheme.charcoal,
              side: const BorderSide(color: MirroraTheme.blushPink),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Tutup',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
