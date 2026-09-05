import 'package:flutter/material.dart';

/// Displays square product artwork without cropping or duplicating the
/// composition. The matte surface owns the intentional letterboxing on wide
/// screens so the artwork stays clear and recognizable.
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
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
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
