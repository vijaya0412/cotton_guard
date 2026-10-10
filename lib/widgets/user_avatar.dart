import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable User Avatar widget that seamlessly renders either a custom persisted photo
/// or a refined agricultural fallback avatar.
class UserAvatar extends StatelessWidget {
  final String? imagePath;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imagePath,
    this.radius = 22,
    this.borderColor,
    this.borderWidth = 1.8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderColor = borderColor ??
        (isDark ? AppColors.secondary.withAlpha(140) : AppColors.primary.withAlpha(90));

    final hasCustomImage = imagePath != null &&
        imagePath!.trim().isNotEmpty &&
        File(imagePath!).existsSync();

    Widget avatarContent;

    if (hasCustomImage) {
      avatarContent = Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(isDark),
      );
    } else {
      avatarContent = _buildDefaultAvatar(isDark);
    }

    final avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: isDark ? const Color(0xFF1E3326) : const Color(0xFFE8F2EC),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: radius * 1.1,
        color: isDark ? AppColors.secondary : AppColors.primary,
      ),
    );
  }
}
