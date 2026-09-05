import 'package:flutter/material.dart';

/// Displays square product artwork without cropping the composition on wide
/// screens. The surrounding surface intentionally owns the letterboxing so
/// the artwork remains complete and the layout stays responsive.
class ContainedHeroImage extends StatelessWidget {
  const ContainedHeroImage({
    super.key,
    required this.assetPath,
    required this.semanticLabel,
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(24),
    ),
    this.backgroundColor,
  });

  final String assetPath;
  final String semanticLabel;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        child: Image.asset(
          key: ValueKey('contained-hero-image-$assetPath'),
          assetPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
