
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/mirrora_theme.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _bucket = 'avatars';

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  late final TextEditingController _usernameController =
      TextEditingController(
    text: widget.user['username'] as String? ?? '',
  );

  Uint8List? _photo;
  String? _avatarPath;
  bool _photoChanged = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.user['photo'] as Uint8List?;
    _avatarPath = widget.user['avatar_path'] as String?;
  }

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

    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      _showMessage('Sesi login berakhir. Silakan login kembali.');
      return;
    }

    final newName = _usernameController.text.trim();
    final oldName = widget.user['username'] as String? ?? '';
    final nameChanged = newName != oldName;

    if (!nameChanged && !_photoChanged) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    String? uploadedPath;
    bool metadataUpdated = false;

    try {
      String? nextAvatarPath = _avatarPath;
      String? nextAvatarUrl =
          currentUser.userMetadata?['avatar_url'] as String?;

      if (_photoChanged && _photo != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        uploadedPath = '${currentUser.id}/avatar_$timestamp.jpg';

        await _supabase.storage.from(_bucket).uploadBinary(
          uploadedPath,
          _photo!,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '3600',
            upsert: false,
          ),
        );

        nextAvatarPath = uploadedPath;
        nextAvatarUrl = _supabase.storage
            .from(_bucket)
            .getPublicUrl(uploadedPath);
      } else if (_photoChanged && _photo == null) {
        nextAvatarPath = null;
        nextAvatarUrl = null;
      }

      final metadata = <String, dynamic>{
        ...?currentUser.userMetadata,
        'username': newName,
      };

      if (_photoChanged) {
        if (nextAvatarPath == null) {
          metadata.remove('avatar_path');
          metadata.remove('avatar_url');
        } else {
          metadata['avatar_path'] = nextAvatarPath;
          metadata['avatar_url'] = nextAvatarUrl;
        }
      }

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: metadata),
      );

      final updatedUser = response.user;

      if (updatedUser == null) {
        throw Exception('Data akun tidak berhasil diperbarui.');
      }

      metadataUpdated = true;

      // Hapus foto lama hanya setelah metadata baru berhasil disimpan.
      if (_photoChanged &&
          _avatarPath != null &&
          _avatarPath != nextAvatarPath) {
        try {
          await _supabase.storage
              .from(_bucket)
              .remove([_avatarPath!]);
        } catch (_) {
          // Foto baru tetap tersimpan meskipun penghapusan foto lama gagal.
        }
      }

      if (!mounted) return;

      Navigator.pop<Map<String, dynamic>>(context, {
        'id': updatedUser.id,
        'username': newName,
        'email': updatedUser.email ?? '',
        'photo': _photo,
        'avatar_path': nextAvatarPath,
        'avatar_url': nextAvatarUrl,
      });
    } catch (error) {
      if (!metadataUpdated && uploadedPath != null) {
        try {
          await _supabase.storage.from(_bucket).remove([uploadedPath]);
        } catch (_) {
          // Pertahankan error utama untuk ditampilkan kepada pengguna.
        }
      }

      _showMessage(
        'Gagal menyimpan profil. Periksa koneksi dan kebijakan Storage, lalu coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _usernameController.text;
    final email = widget.user['email'] as String? ?? '';

    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
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
                  child: ProfileAvatar(
                    name: previewName.isEmpty
                        ? (widget.user['username'] as String? ?? '')
                        : previewName,
                    photo: _photo,
                    size: 128,
                    showCamera: true,
                    onTap: _pickPhoto,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : _pickPhoto,
                      child: const Text('Ganti Foto'),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: _isSaving ? null : _removePhoto,
                        child: const Text(
                          'Hapus Foto',
                          style: TextStyle(
                            color: MirroraTheme.warmGray,
                          ),
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
                  enabled: !_isSaving,
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
                  initialValue: email,
                  readOnly: true,
                  enabled: false,
                  style: const TextStyle(
                    color: MirroraTheme.warmGray,
                  ),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
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
