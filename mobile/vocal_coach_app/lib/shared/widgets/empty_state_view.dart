import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Animated empty state with illustration, headline, body, and optional CTA.
///
/// Displays a Lottie animation (or custom widget, or fallback icon) with
/// supporting text and an optional call-to-action button that pulses subtly
/// to draw attention.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.headline,
    required this.body,
    this.lottieAsset,
    this.customAnimation,
    this.ctaLabel,
    this.onCtaTap,
    this.illustrationSize = 200.0,
    this.ctaPulseInterval = const Duration(milliseconds: 3000),
  });

  final String headline;
  final String body;

  /// Path to a Lottie JSON asset (e.g. `assets/animations/empty.json`).
  final String? lottieAsset;

  /// Custom animation widget to use instead of Lottie.
  final Widget? customAnimation;

  /// Label for the call-to-action button. If null, no CTA is shown.
  final String? ctaLabel;

  /// Callback when the CTA button is tapped.
  final VoidCallback? onCtaTap;

  /// Maximum size for the illustration area (width and height).
  final double illustrationSize;

  /// Interval at which the CTA button pulses.
  final Duration ctaPulseInterval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIllustration(theme),
            const SizedBox(height: 16),
            Text(
              headline,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: 16),
              _PulsingButton(
                label: ctaLabel!,
                onTap: onCtaTap!,
                pulseInterval: ctaPulseInterval,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(ThemeData theme) {
    if (customAnimation != null) {
      return SizedBox(
        width: illustrationSize,
        height: illustrationSize,
        child: customAnimation,
      );
    }

    if (lottieAsset != null) {
      return SizedBox(
        width: illustrationSize,
        height: illustrationSize,
        child: Lottie.asset(
          lottieAsset!,
          repeat: true,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.inbox_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            );
          },
        ),
      );
    }

    // Default fallback: static icon.
    return SizedBox(
      width: illustrationSize,
      height: illustrationSize,
      child: Icon(
        Icons.inbox_outlined,
        size: 80,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A button that pulses (scale 1.0 → 1.04 → 1.0) on a repeating interval.
class _PulsingButton extends StatefulWidget {
  const _PulsingButton({
    required this.label,
    required this.onTap,
    required this.pulseInterval,
  });

  final String label;
  final VoidCallback onTap;
  final Duration pulseInterval;

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pulseInterval,
    );

    // Pulse occupies a brief portion of the interval: scale up then down.
    // Use a TweenSequence to go 1.0 → 1.04 → 1.0 in the first ~20% of
    // the interval, then hold at 1.0 for the remaining 80% (the pause).
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 80,
      ),
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: FilledButton(
        onPressed: widget.onTap,
        child: Text(widget.label),
      ),
    );
  }
}
