import 'package:flutter/material.dart';

/// Wraps any child with press-scale feedback.
///
/// On tap down, the child scales to [scaleDown] over [pressDuration].
/// On tap up/cancel, it scales back to 1.0 over [releaseDuration].
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.96,
    this.pressDuration = const Duration(milliseconds: 100),
    this.releaseDuration = const Duration(milliseconds: 200),
  });

  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;
  final Duration pressDuration;
  final Duration releaseDuration;

  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
      value: 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final scale =
              1.0 - (1.0 - widget.scaleDown) * _animation.value;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A card variant of [Pressable] that also animates elevation during press.
///
/// Scales to [scaleDown] (default 0.97) and increases elevation from
/// [baseElevation] to [pressedElevation] on tap.
class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.97,
    this.pressDuration = const Duration(milliseconds: 100),
    this.releaseDuration = const Duration(milliseconds: 200),
    this.baseElevation = 2.0,
    this.pressedElevation = 8.0,
    this.borderRadius = 24.0,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;
  final Duration pressDuration;
  final Duration releaseDuration;
  final double baseElevation;
  final double pressedElevation;
  final double borderRadius;

  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
      value: 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final scale =
              1.0 - (1.0 - widget.scaleDown) * _animation.value;
          final elevation = widget.baseElevation +
              (widget.pressedElevation - widget.baseElevation) *
                  _animation.value;
          return Transform.scale(
            scale: scale,
            child: Card(
              elevation: elevation,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(widget.borderRadius),
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
