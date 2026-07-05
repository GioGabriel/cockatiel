import 'package:flutter/material.dart';

/// Gold color for personal best glow accent.
const _kGoldColor = Color(0xFFE1B261);

/// Score display that chains count-up → pulse → optional gold glow.
///
/// Uses [TickerProviderStateMixin] to manage multiple [AnimationController]s:
/// - Controller 1: count-up from 0 to [score] over [countUpDuration]
/// - Controller 2: pulse scale 1.0→1.08→1.0 over [pulseDuration]
/// - Controller 3 (if [isPersonalBest]): gold glow fade-out over [glowDuration]
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

    // When pulse starts, trigger glow if applicable.
    _pulseController.addStatusListener(_onPulseStatus);
  }

  void _initGlow() {
    _glowController = AnimationController(
      vsync: this,
      duration: widget.glowDuration,
    );
    // Glow: fade in quickly then fade out.
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
        final glowOpacity = _glowAnimation?.value ?? 0.0;

        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: widget.isPersonalBest && glowOpacity > 0
                ? BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kGoldColor.withValues(
                          alpha: glowOpacity * 0.6,
                        ),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
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
