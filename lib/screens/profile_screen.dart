import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/mirrora_theme.dart';
import '../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userName,
    required this.onProfileChanged,
  });

  final String userName;

  /// Dipanggil setelah username berubah, supaya Home ikut diperbarui.
  final ValueChanged<String> onProfileChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _user;

  String get _name => (_user?['username'] as String?) ?? widget.userName;
  String get _email => (_user?['email'] as String?) ?? '';
  Uint8List? get _photo => _user?['photo'] as Uint8List?;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _auth.currentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature segera hadir')));
  }

  Future<void> _openEditProfile() async {
    final user = _user;
    if (user == null) return;

    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );

    if (updated == null || !mounted) return;

    setState(() => _user = updated);
    widget.onProfileChanged(updated['username'] as String);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
        content: const Text(
          'Yakin mau keluar dari Mirrora?',
          style: TextStyle(fontSize: 14, color: MirroraTheme.warmGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: MirroraTheme.warmGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _auth.logout();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Profil',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                onTap: _openEditProfile,
                child: ProfileAvatar(
                  name: _name,
                  photo: _photo,
                  size: 120,
                  showCamera: true,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: MirroraTheme.warmGray,
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: MirroraTheme.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: MirroraTheme.blushPink),
              ),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profil',
                    onTap: _openEditProfile,
                  ),
                  const _MenuDivider(),
                  _MenuTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Self-Care Journal',
                    onTap: () => _comingSoon('Self-Care Journal'),
                  ),
                  const _MenuDivider(),
                  _MenuTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Achievement',
                    onTap: () => _comingSoon('Achievement'),
                  ),
                  const _MenuDivider(),
                  _MenuTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Saran & Kesan',
                    onTap: () => _comingSoon('Saran & Kesan'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MirroraTheme.blushPink,
                foregroundColor: MirroraTheme.charcoal,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: MirroraTheme.dustyRose),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: MirroraTheme.warmGray,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 70,
      endIndent: 16,
      color: MirroraTheme.blushPink,
    );
  }
}