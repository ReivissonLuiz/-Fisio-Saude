/// widgets/password_strength_indicator.dart
/// Indicador visual de força da senha (fraca / média / forte).

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PasswordStrength { empty, weak, medium, strong }

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  PasswordStrength get strength {
    if (password.isEmpty) return PasswordStrength.empty;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$&*~%^()_+=\-]'))) score++;
    if (score <= 1) return PasswordStrength.weak;
    if (score == 2 || score == 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final s = strength;
    final Color color = switch (s) {
      PasswordStrength.weak => AppTheme.error,
      PasswordStrength.medium => AppTheme.warning,
      PasswordStrength.strong => AppTheme.accent,
      PasswordStrength.empty => Colors.transparent,
    };
    final String label = switch (s) {
      PasswordStrength.weak => 'Fraca',
      PasswordStrength.medium => 'Média',
      PasswordStrength.strong => 'Forte',
      PasswordStrength.empty => '',
    };
    final int filledBars = switch (s) {
      PasswordStrength.weak => 1,
      PasswordStrength.medium => 2,
      PasswordStrength.strong => 3,
      PasswordStrength.empty => 0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filledBars ? color : AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'Força da senha: $label',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
