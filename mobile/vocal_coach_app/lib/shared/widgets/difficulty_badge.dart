import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({
    super.key,
    required this.difficulty,
  });

  final String difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String label;
    final Color color;

    switch (difficulty.toLowerCase()) {
      case 'beginner':
        label = 'Beginner';
        color = theme.appTokens.success;
        break;
      case 'intermediate':
        label = 'Intermediate';
        color = theme.appTokens.warning;
        break;
      case 'advanced':
        label = 'Advanced';
        color = theme.appTokens.danger;
        break;
      default:
        label = difficulty.isNotEmpty
            ? difficulty[0].toUpperCase() + difficulty.substring(1)
            : '';
        color = theme.colorScheme.onSurfaceVariant;
    }

    return Semantics(
      label: 'Difficulty: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
