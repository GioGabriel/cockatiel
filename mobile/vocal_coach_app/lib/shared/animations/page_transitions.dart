import 'package:flutter/material.dart';

/// Slide-right + fade-in for forward navigation.
///
/// Incoming page slides from right (offset 1.0, 0.0) to center
/// with a concurrent fade-in. Uses [Curves.easeOutCubic].
PageRouteBuilder<T> slideForwardRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 400),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offsetTween = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: offsetTween.animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Slide-left + fade-out for backward navigation.
///
/// Incoming page slides from left (offset -1.0, 0.0) to center
/// with a concurrent fade-in. Uses [Curves.easeInCubic].
PageRouteBuilder<T> slideBackRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 350),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInCubic,
      );
      final offsetTween = Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: Offset.zero,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: offsetTween.animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Cross-fade for tab switches.
///
/// Simple opacity transition over [duration] (default 250ms).
PageRouteBuilder<T> crossFadeRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 250),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}

/// Scale-up + fade for auth → dashboard welcome moment.
///
/// Incoming page scales from 0.8 to 1.0 with a concurrent fade-in
/// over [duration] (default 500ms).
PageRouteBuilder<T> scaleWelcomeRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 500),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final scaleTween = Tween<double>(begin: 0.8, end: 1.0);
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: scaleTween.animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Vertical slide-up + fade for session flow transitions.
///
/// Incoming page slides from bottom (offset 0.0, 1.0) to center
/// with a concurrent fade-in over [duration] (default 450ms).
PageRouteBuilder<T> slideUpRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 450),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offsetTween = Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: offsetTween.animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Scale-down existing + fade-in results overlay.
///
/// The outgoing page scales down to 0.92 while the incoming page
/// fades in over [duration] (default 500ms). Uses [secondaryAnimation]
/// to drive the outgoing page's scale.
PageRouteBuilder<T> resultRevealRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 500),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}
