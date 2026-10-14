
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/mirrora_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 112,
    this.showCamera = false,
    this.onTap,
  });

  final String name;
  final Uint8List? photo;
  final double size;
  final bool showCamera;
  final VoidCallback? onTap;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MirroraTheme.blushPink,
              shape: BoxShape.circle,
              border: Border.all(
                color: MirroraTheme.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: MirroraTheme.dustyRose.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
              image: photo == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(photo!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: photo == null
                ? Text(
                    _initial,
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.dustyRose,
                    ),
                  )
                : null,
          ),
          if (showCamera)
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: MirroraTheme.dustyRose,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: size * 0.3,
                    height: size * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MirroraTheme.white,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: size * 0.15,
                      color: MirroraTheme.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
