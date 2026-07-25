import 'package:flutter/material.dart';

/// Premium solid matte surface card (Spotify/studio style).
///
/// Renders a clean, high-contrast dark surface card with subtle borders
/// without using glassmorphism blur or heavy gradients.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.blurSigma = 0.0,
    this.fillColor,
    this.borderRadius = 24.0,
    this.borderOpacity = 0.08,
  }) : _isDisabled = false;

  /// Dark variant for session overlays with solid Spotify matte surface.
  const GlassCard.dark({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.borderOpacity = 0.12,
  })  : blurSigma = 0.0,
        fillColor = const Color(0xFF181818),
        _isDisabled = false;

  /// Disabled variant that renders a flat opaque card (performance fallback).
  const GlassCard.disabled({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
  })  : blurSigma = 0.0,
        fillColor = null,
        borderOpacity = 0.0,
        _isDisabled = true;

  final Widget child;
  final double blurSigma;
  final Color? fillColor;
  final double borderRadius;
  final double borderOpacity;
  final bool _isDisabled;

  @override
  Widget build(BuildContext context) {
    if (_isDisabled) {
      return _buildDisabledCard(context);
    }
    return _buildMatteCard(context);
  }

  Widget _buildMatteCard(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedFillColor =
        fillColor ?? (theme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5));
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: resolvedFillColor,
        borderRadius: radius,
        border: borderOpacity > 0
            ? Border.all(
                color: Colors.white.withValues(alpha: borderOpacity),
                width: 1,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: child,
      ),
    );
  }

  Widget _buildDisabledCard(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: radius,
      ),
      child: child,
    );
  }
}
