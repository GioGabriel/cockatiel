import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Displays square product artwork as a full-bleed hero without cropping the
/// primary composition. A softened, dimmed copy fills the panel while the
/// complete source artwork remains visible in the foreground.
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.asset(
                key: ValueKey('contained-hero-image-background-$assetPath'),
                assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                excludeFromSemantics: true,
              ),
            ),
            ColoredBox(
              color: theme.colorScheme.scrim.withValues(alpha: 0.58),
            ),
            Image.asset(
              key: ValueKey('contained-hero-image-$assetPath'),
              assetPath,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              semanticLabel: semanticLabel,
            ),
          ],
        ),
      ),
    );
  }
}
