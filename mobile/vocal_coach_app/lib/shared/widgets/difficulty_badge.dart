import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        color = const Color(0xFF34D399); // theme.colorScheme.success
        break;
      case 'intermediate':
        label = 'Intermediate';
        color = const Color(0xFFFBBF24); // theme.colorScheme.warn
        break;
      case 'advanced':
        label = 'Advanced';
        color = const Color(0xFFF87171); // theme.colorScheme.danger
        break;
      default:
        label = difficulty.isNotEmpty
            ? difficulty[0].toUpperCase() + difficulty.substring(1)
            : '';
        color = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
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
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
