import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Displays a shimmer placeholder matching the given layout shape.
///
/// Wraps a child widget (typically a shaped [Container]) with
/// the shimmer sweep animation. Colors default to theme surface
/// at 100% transitioning through 40% opacity.
class ShimmerSkeleton extends StatelessWidget {
  const ShimmerSkeleton({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1200),
  });

  /// The "shape" widget (Container with rounded rect, sized to match
  /// real content).
  final Widget child;

  /// Base color for the shimmer gradient.
  /// Defaults to [ColorScheme.surface] from the current theme.
  final Color? baseColor;

  /// Highlight color for the shimmer gradient sweep.
  /// Defaults to [ColorScheme.surface] at 40% opacity.
  final Color? highlightColor;

  /// Duration of one full shimmer sweep cycle.
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = baseColor ?? theme.colorScheme.surface;
    final highlight =
        highlightColor ?? theme.colorScheme.surface.withValues(alpha: 0.4);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: period,
      child: child,
    );
  }
}

/// Pre-built skeleton shapes for common screen layouts.
///
/// Each factory method returns a sized and shaped container that
/// matches the dimensions of the real content it replaces.
class SkeletonShapes {
  SkeletonShapes._();

  /// Skeleton matching a dashboard module/progress card.
  /// Height ~120, rounded corners 24, full width.
  static Widget dashboardCard({required ThemeData theme}) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  /// Skeleton matching a training/karaoke catalog list item.
  /// Height ~72, rounded corners 12, full width.
  static Widget listItem({required ThemeData theme}) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// Skeleton matching a chart block on the analytics page.
  /// Height ~200, rounded corners 16, full width.
  static Widget chartBlock({required ThemeData theme}) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  /// Skeleton matching a row of stat pills on the analytics/dashboard page.
  /// Three evenly spaced rounded containers.
  static Widget statRow({required ThemeData theme}) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            height: 48,
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == 2 ? 0 : 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }),
    );
  }
}
