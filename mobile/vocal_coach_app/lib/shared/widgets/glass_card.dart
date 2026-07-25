import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass card with backdrop blur and translucent fill.
///
/// Uses [ClipRRect] + [BackdropFilter] with [ImageFilter.blur] to achieve
/// a glassmorphism effect. Performance constraint: max 3 [GlassCard]
/// instances per visible screen to maintain 60fps on mid-range Android.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.blurSigma = 12.0,
    this.fillColor,
    this.borderRadius = 24.0,
    this.borderOpacity = 0.3,
  }) : _isDisabled = false;

  /// Dark variant for session overlays with stronger blur and dark fill.
  const GlassCard.dark({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.borderOpacity = 0.3,
  })  : blurSigma = 16.0,
        fillColor = const Color(0x66000000),
        _isDisabled = false;

  /// Disabled variant that renders a flat opaque card (performance fallback).
  /// Bypasses [BackdropFilter] entirely and uses the theme's surface color.
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

  Widget build(BuildContext context) {
    if (_isDisabled) {
      return _buildDisabledCard(context);
    }
    return _buildGlassCard();
  }

  Widget _buildGlassCard() {
    final resolvedFillColor =
        fillColor ?? Colors.white.withValues(alpha: 0.7);
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: resolvedFillColor,
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1,
            ),
          ),
          child: child,
        ),
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
