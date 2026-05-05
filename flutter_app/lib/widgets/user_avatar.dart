/// user_avatar.dart
/// Widget reutilizável de avatar de usuário — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String nome;
  final double radius;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.nome,
    this.avatarUrl,
    this.radius = 24,
    this.backgroundColor,
    this.onTap,
  });

  String get _inicial =>
      nome.trim().isNotEmpty ? nome.trim()[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primary;

    Widget avatar;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: bg.withValues(alpha: 0.1),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bg.withValues(alpha: 0.15),
        child: Text(
          _inicial,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: bg,
          ),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
