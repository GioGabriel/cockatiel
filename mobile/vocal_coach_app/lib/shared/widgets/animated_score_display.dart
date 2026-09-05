import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

/// Score display that chains count-up → pulse → optional personal-best highlight.
///
/// Uses [TickerProviderStateMixin] to manage multiple [AnimationController]s:
/// - Controller 1: count-up from 0 to [score] over [countUpDuration]
/// - Controller 2: pulse scale 1.0→1.08→1.0 over [pulseDuration]
/// - Controller 3 (if [isPersonalBest]): a restrained highlight fade-out over
///   [glowDuration]
class AnimatedScoreDisplay extends StatefulWidget {
  const AnimatedScoreDisplay({
    super.key,
    required this.score,
    this.isPersonalBest = false,
    this.countUpDuration = const Duration(milliseconds: 800),
    this.pulseDuration = const Duration(milliseconds: 300),
    this.glowDuration = const Duration(milliseconds: 600),
    this.style,
  });

  final int score;
  final bool isPersonalBest;
  final Duration countUpDuration;
  final Duration pulseDuration;
  final Duration glowDuration;
  final TextStyle? style;

  @override
  State<AnimatedScoreDisplay> createState() => _AnimatedScoreDisplayState();
}

class _AnimatedScoreDisplayState extends State<AnimatedScoreDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _countUpController;
  late final AnimationController _pulseController;
  AnimationController? _glowController;

  late Animation<double> _countUpAnimation;
  late Animation<double> _pulseAnimation;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initCountUp();
    _initPulse();
    if (widget.isPersonalBest) {
      _initGlow();
    }
    _countUpController.forward();
  }

  void _initCountUp() {
    _countUpController = AnimationController(
      vsync: this,
      duration: widget.countUpDuration,
    );
    _countUpAnimation = Tween<double>(
      begin: 0,
      end: widget.score.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _countUpController,
        curve: Curves.easeOutCubic,
      ),
    );
    // When count-up completes, trigger pulse.
    _countUpController.addStatusListener(_onCountUpStatus);
  }

  void _initPulse() {
    _pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    );
    // Pulse: 1.0 → 1.08 → 1.0 using a TweenSequence.
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    // When pulse starts, trigger the personal-best highlight if applicable.
    _pulseController.addStatusListener(_onPulseStatus);
  }

  void _initGlow() {
    _glowController = AnimationController(
      vsync: this,
      duration: widget.glowDuration,
    );
    // Highlight: fade in quickly then fade out.
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_glowController!);
  }

  void _onCountUpStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _pulseController.forward();
    }
  }

  void _onPulseStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward && mounted) {
      _glowController?.forward();
    }
  }

  @override
  void dispose() {
    _countUpController.removeStatusListener(_onCountUpStatus);
    _pulseController.removeStatusListener(_onPulseStatus);
    _countUpController.dispose();
    _pulseController.dispose();
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ??
        Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            );

    return AnimatedBuilder(
      animation: Listenable.merge([
        _countUpAnimation,
        _pulseAnimation,
        if (_glowAnimation != null) _glowAnimation!,
      ]),
      builder: (context, child) {
        final highlightOpacity = _glowAnimation?.value ?? 0.0;
        final theme = Theme.of(context);

        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: widget.isPersonalBest && highlightOpacity > 0
                ? BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.appTokens.warning.withValues(
                        alpha: highlightOpacity * 0.7,
                      ),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _countUpAnimation.value.round().toString(),
              style: textStyle,
            ),
          ),
        );
      },
    );
  }
}
