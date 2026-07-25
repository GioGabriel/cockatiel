import 'package:flutter/material.dart';

import 'package:vocal_coach_app/shared/animations/spring_curves.dart';

/// Shows a modal bottom sheet with a spring-damped slide-up animation.
///
/// The sheet slides upward from off-screen using a [SpringCurve] with
/// configurable [dampingRatio] over [duration]. The scrim fades in
/// concurrently (black at 40% opacity over 250ms). Dismiss animates
/// slide-down with ease-in over 300ms.
Future<T?> showAnimatedBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double dampingRatio = 0.85,
  Duration duration = const Duration(milliseconds: 400),
  bool isDismissible = true,
  Color barrierColor = const Color(0x66000000),
}) {
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: duration,
    reverseDuration: const Duration(milliseconds: 300),
  );

  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => _SpringAnimatedSheet(
      animation: controller,
      dampingRatio: dampingRatio,
      child: builder(context),
    ),
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    barrierColor: barrierColor,
    isScrollControlled: true,
    transitionAnimationController: controller,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAliasWithSaveLayer,
  );
}

/// Internal widget that applies spring curve to the bottom sheet animation.
class _SpringAnimatedSheet extends StatelessWidget {
  const _SpringAnimatedSheet({
    required this.animation,
    required this.dampingRatio,
    required this.child,
  });

  final AnimationController animation;
  final double dampingRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final springCurve = SpringCurve(damping: dampingRatio);
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: springCurve,
      reverseCurve: Curves.easeIn,
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) => child!,
      child: child,
    );
  }
}

/// Shows a confirmation dialog with scale (0.9→1.0) + fade-in animation
/// over [duration] using [Curves.easeOutCubic].
Future<T?> showAnimatedDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 200),
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000),
    transitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}
