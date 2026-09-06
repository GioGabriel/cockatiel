import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short, deterministic brand entrance that works in Chrome and on Android.
///
/// The artwork is intentionally a normal Flutter asset instead of a web-only
/// animation. Flutter owns the motion, so the splash has the same lifecycle,
/// accessibility behavior, and test surface on every supported platform.
class AnimatedCockatielSplash extends StatefulWidget {
  const AnimatedCockatielSplash({
    super.key,
    this.showProgress = false,
    this.assetPath = 'assets/images/cockatiel_splash_hero_v2.png',
  });

  final bool showProgress;
  final String assetPath;

  @override
  State<AnimatedCockatielSplash> createState() =>
      _AnimatedCockatielSplashState();
}

class _AnimatedCockatielSplashState extends State<AnimatedCockatielSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;
  late final Animation<double> _notes;
  late final Animation<double> _settle;
  bool _motionDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2_200),
    )..forward();
    _entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.58, curve: Curves.easeOutCubic),
    );
    _notes = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.82, curve: Curves.easeOutCubic),
    );
    _settle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 1, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motionDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (motionDisabled == _motionDisabled) {
      return;
    }

    _motionDisabled = motionDisabled;
    if (motionDisabled) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: 'Preparing Cockatiel vocal coaching',
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final reservedForCopy = widget.showProgress ? 150.0 : 96.0;
              final availableArtworkHeight = math.max(
                0.0,
                constraints.maxHeight - reservedForCopy,
              );
              final artworkHeight = math.min(
                availableArtworkHeight,
                math.min(
                  constraints.maxHeight * 0.68,
                  constraints.maxWidth * 1.08,
                ),
              );
              return AnimatedBuilder(
                animation: _controller,
                child: RepaintBoundary(
                  child: _SplashArtwork(
                    assetPath: widget.assetPath,
                    primaryColor: colorScheme.primary,
                    secondaryColor: colorScheme.secondary,
                  ),
                ),
                builder: (context, child) {
                  final progress = _motionDisabled ? 1.0 : _controller.value;
                  final entrance = _motionDisabled ? 1.0 : _entrance.value;
                  final notes = _motionDisabled ? 1.0 : _notes.value;
                  final settle = _motionDisabled ? 1.0 : _settle.value;
                  final contentOpacity = _opacity(progress, 0.52, 0.86);

                  return Column(
                    children: [
                      SizedBox(
                        height: artworkHeight,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform.translate(
                              offset: Offset(
                                -constraints.maxWidth * 0.14 * (1 - entrance),
                                constraints.maxHeight *
                                        0.055 *
                                        (1 - entrance) -
                                    constraints.maxHeight * 0.012 * settle,
                              ),
                              child: Transform.rotate(
                                angle: -0.035 * (1 - entrance) +
                                    math.sin(settle * math.pi) * 0.008,
                                child: Transform.scale(
                                  scale: 0.9 + entrance * 0.1,
                                  child: Opacity(
                                    opacity: _opacity(entrance, 0, 0.5),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey(
                                  'cockatiel-splash-motion-layer',
                                ),
                                painter: _SplashMotionPainter(
                                  entranceProgress: entrance,
                                  noteProgress: notes,
                                  settleProgress: settle,
                                  primaryColor: colorScheme.primary,
                                  secondaryColor: colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: contentOpacity,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - contentOpacity)),
                          child: Column(
                            children: [
                              Text(
                                'Cockatiel',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Voice practice, made clear',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (widget.showProgress) ...[
                                const SizedBox(height: 32),
                                Semantics(
                                  label: 'Loading your vocal coach',
                                  child: SizedBox(
                                    key: const ValueKey(
                                      'cockatiel-splash-progress',
                                    ),
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  double _opacity(double progress, double start, double end) {
    if (progress <= start) {
      return 0;
    }
    if (progress >= end) {
      return 1;
    }
    return Curves.easeOut.transform((progress - start) / (end - start));
  }
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({
    required this.assetPath,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String assetPath;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cockatiel vocal coaching artwork',
      image: true,
      child: Image.asset(
        key: const ValueKey('cockatiel-splash-artwork'),
        assetPath,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox.expand(
            child: CustomPaint(
              key: const ValueKey('cockatiel-splash-artwork-fallback'),
              painter: _SplashFallbackPainter(
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplashMotionPainter extends CustomPainter {
  const _SplashMotionPainter({
    required this.entranceProgress,
    required this.noteProgress,
    required this.settleProgress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double entranceProgress;
  final double noteProgress;
  final double settleProgress;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final waveformPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.34)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final waveform = Path();
    final baseline = size.height * 0.76;
    for (var index = 0; index <= 36; index++) {
      final x = size.width * index / 36;
      final pulse = math.sin(index * 0.92 + settleProgress * math.pi * 2);
      final amplitude = size.height * (0.008 + pulse.abs() * 0.022);
      final y = baseline +
          math.sin(index * 0.7 + settleProgress * 2) * amplitude;
      if (index == 0) {
        waveform.moveTo(x, y);
      } else {
        waveform.lineTo(x, y);
      }
    }
    canvas.drawPath(waveform, waveformPaint);

    final notePaint = Paint()
      ..color = secondaryColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final noteOrigins = [
      Offset(size.width * 0.22, size.height * 0.30),
      Offset(size.width * 0.68, size.height * 0.22),
      Offset(size.width * 0.82, size.height * 0.38),
      Offset(size.width * 0.38, size.height * 0.18),
    ];

    for (var index = 0; index < noteOrigins.length; index++) {
      final delay = index * 0.12;
      final localProgress =
          ((noteProgress - delay) / 0.72).clamp(0.0, 1.0).toDouble();
      final fall = Curves.easeOutCubic.transform(localProgress);
      final drift = math.sin((localProgress + index) * math.pi) * 10;
      final position = noteOrigins[index] +
          Offset(drift, size.height * 0.22 * fall);
      final fadeIn = (localProgress / 0.16).clamp(0.0, 1.0).toDouble();
      final fadeOut =
          ((1 - localProgress) / 0.22).clamp(0.0, 1.0).toDouble();
      final opacity = (fadeIn * fadeOut * 0.9).clamp(0.0, 1.0).toDouble();
      _drawNote(
        canvas,
        position,
        notePaint..color = secondaryColor.withValues(alpha: opacity),
        flipped: index.isOdd,
      );
    }

    final entranceLinePaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.12 * entranceProgress)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final arc = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.46),
      width: size.width * 0.72,
      height: size.height * 0.34,
    );
    canvas.drawArc(arc, math.pi * 1.05, math.pi * 0.72, false, entranceLinePaint);
  }

  void _drawNote(
    Canvas canvas,
    Offset origin,
    Paint paint, {
    required bool flipped,
  }) {
    final stemDirection = flipped ? -1.0 : 1.0;
    final stemTop = origin.translate(0, -22 * stemDirection);
    canvas.drawOval(
      Rect.fromCenter(center: origin, width: 13, height: 9),
      paint,
    );
    canvas.drawLine(origin, stemTop, paint);
    canvas.drawLine(
      stemTop,
      stemTop.translate(10 * stemDirection, 7 * stemDirection),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashMotionPainter oldDelegate) {
    return oldDelegate.entranceProgress != entranceProgress ||
        oldDelegate.noteProgress != noteProgress ||
        oldDelegate.settleProgress != settleProgress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class _SplashFallbackPainter extends CustomPainter {
  const _SplashFallbackPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.46, size.height * 0.42);
    final bodyPaint = Paint()..color = secondaryColor.withValues(alpha: 0.82);
    final wingPaint = Paint()..color = primaryColor.withValues(alpha: 0.75);
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, size.height * 0.08),
        width: size.width * 0.3,
        height: size.height * 0.38,
      ),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-size.width * 0.06, -size.height * 0.08),
        width: size.width * 0.27,
        height: size.height * 0.2,
      ),
      bodyPaint,
    );

    final wing = Path()
      ..moveTo(center.dx - size.width * 0.06, center.dy)
      ..quadraticBezierTo(
        center.dx - size.width * 0.4,
        center.dy - size.height * 0.22,
        center.dx - size.width * 0.26,
        center.dy + size.height * 0.24,
      )
      ..close();
    canvas.drawPath(wing, wingPaint);

    canvas.drawCircle(
      center.translate(size.width * 0.11, -size.height * 0.1),
      size.width * 0.015,
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.68),
      Offset(size.width * 0.88, size.height * 0.68),
      linePaint,
    );
    for (var index = 0; index < 22; index++) {
      final x = size.width * index / 21;
      final height = size.height * (0.012 + (index % 3) * 0.014);
      canvas.drawLine(
        Offset(x, size.height * 0.68 - height),
        Offset(x, size.height * 0.68 + height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashFallbackPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
