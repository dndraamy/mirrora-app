import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../theme/mirrora_theme.dart';
import '../widgets/profile_avatar.dart';

/// Ubah foto profil dan username. Mengembalikan data user terbaru via pop().
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _usernameController = TextEditingController(
    text: widget.user['username'] as String,
  );
  late Uint8List? _photo = widget.user['photo'] as Uint8List?;

  bool _photoChanged = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _photo = bytes;
        _photoChanged = true;
      });
    } catch (_) {
      _showMessage('Foto tidak dapat dipilih. Coba lagi.');
    }
  }

  void _removePhoto() {
    setState(() {
      _photo = null;
      _photoChanged = true;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final newName = _usernameController.text.trim();
    final nameChanged = newName != widget.user['username'];

    if (!nameChanged && !_photoChanged) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await _auth.updateProfile(
        username: nameChanged ? newName : null,
        photo: _photoChanged ? _photo : null,
        removePhoto: _photoChanged && _photo == null,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _usernameController.text;

    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        title: const Text(
          'Edit Profil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: ProfileAvatar(
                      name: previewName.isEmpty
                          ? widget.user['username'] as String
                          : previewName,
                      photo: _photo,
                      size: 128,
                      showCamera: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _pickPhoto,
                      child: const Text('Ganti Foto'),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: _removePhoto,
                        child: const Text(
                          'Hapus Foto',
                          style: TextStyle(color: MirroraTheme.warmGray),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Username',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 9),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Username minimal 3 karakter';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Masukkan username',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: MirroraTheme.dustyRose,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 9),
                TextFormField(
                  initialValue: widget.user['email'] as String,
                  readOnly: true,
                  enabled: false,
                  style: const TextStyle(color: MirroraTheme.warmGray),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Simpan',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
