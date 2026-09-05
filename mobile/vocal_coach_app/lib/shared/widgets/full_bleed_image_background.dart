import 'package:flutter/material.dart';

/// A full-screen image treatment used by the entry experience.
///
/// The artwork stays edge-to-edge while a restrained dark overlay keeps text
/// and controls readable. This intentionally matches the established
/// Cockatiel onboarding/auth composition instead of introducing a second
/// contained-image layout with visible letterboxing.
class FullBleedImageBackground extends StatelessWidget {
  const FullBleedImageBackground({
    super.key,
    required this.assetPath,
    required this.semanticLabel,
    required this.child,
    this.overlayColor = const Color(0xFF09090F),
  });

  final String assetPath;
  final String semanticLabel;
  final Widget child;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          key: ValueKey('full-bleed-image-$assetPath'),
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          semanticLabel: semanticLabel,
        ),
        DecoratedBox(
          key: ValueKey('full-bleed-image-overlay-$assetPath'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.30, 0.50, 1.0],
              colors: [
                overlayColor.withValues(alpha: 0.15),
                overlayColor.withValues(alpha: 0.55),
                overlayColor.withValues(alpha: 0.92),
                overlayColor,
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
