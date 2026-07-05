import 'package:flutter/material.dart';

/// Maximum number of items that receive staggered animation.
/// Items beyond this index appear instantly to avoid multi-second delays.
const int _kMaxStaggerItems = 10;

/// Wraps a list of children with staggered fade + slide entrance animation.
///
/// Only animates on first build — subsequent rebuilds show children directly.
/// Uses a single [AnimationController] with staggered [Interval]s per child.
///
/// Each child fades from 0→1 opacity and translates from [slideOffset] pixels
/// below its final position to its resting position, staggered by
/// [staggerDelay] per item.
///
/// Performance: caps animation to the first 10 items; remaining appear
/// instantly.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.slideOffset = 24.0,
    this.curve = Curves.easeOutCubic,
  });

  /// The widgets to animate into view.
  final List<Widget> children;

  /// Delay between each child's animation start.
  final Duration staggerDelay;

  /// Duration of each individual child's fade + slide animation.
  final Duration itemDuration;

  /// Vertical offset (in logical pixels) from which children slide up.
  final double slideOffset;

  /// Curve applied to each child's animation interval.
  final Curve curve;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    final totalDuration = _calculateTotalDuration();
    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );

    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _hasAnimated = true;
        });
      }
    });
  }

  Duration _calculateTotalDuration() {
    final animatedCount = widget.children.length.clamp(0, _kMaxStaggerItems);
    if (animatedCount == 0) return Duration.zero;
    final totalMs =
        widget.staggerDelay.inMilliseconds * animatedCount +
        widget.itemDuration.inMilliseconds;
    return Duration(milliseconds: totalMs);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // After first animation completes, show children directly.
    if (_hasAnimated) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.children,
      );
    }

    final totalDurationMs = _calculateTotalDuration().inMilliseconds;
    if (totalDurationMs == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.children,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.children.length, (index) {
        // Items beyond the cap appear instantly without animation.
        if (index >= _kMaxStaggerItems) {
          return widget.children[index];
        }

        final startMs = index * widget.staggerDelay.inMilliseconds;
        final endMs = startMs + widget.itemDuration.inMilliseconds;

        final start = startMs / totalDurationMs;
        final end = (endMs / totalDurationMs).clamp(0.0, 1.0);

        final interval = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: widget.curve),
        );

        final slideAnimation = Tween<Offset>(
          begin: Offset(0, widget.slideOffset),
          end: Offset.zero,
        ).animate(interval);

        return FadeTransition(
          opacity: interval,
          child: _SlideTranslation(
            offset: slideAnimation,
            child: widget.children[index],
          ),
        );
      }),
    );
  }
}

/// Translates a child by pixel [offset] driven by an animation.
///
/// Unlike [SlideTransition] which uses fractional offsets relative to
/// child size, this applies an exact pixel translation for precise
/// entrance positioning.
class _SlideTranslation extends AnimatedWidget {
  const _SlideTranslation({
    required Animation<Offset> offset,
    required this.child,
  }) : super(listenable: offset);

  final Widget child;

  Animation<Offset> get _offset => listenable as Animation<Offset>;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset.value,
      child: child,
    );
  }
}
