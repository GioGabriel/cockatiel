import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded startup artwork with a small, native Flutter motion system.
///
/// This intentionally uses Flutter's animation primitives instead of adding a
/// web-only animation dependency such as GSAP. The same widget therefore works
/// in Chrome and on Android, and it can be tested without a browser runtime.
class AnimatedCockatielSplash extends StatefulWidget {
  const AnimatedCockatielSplash({
    super.key,
    this.showProgress = false,
  });

  final bool showProgress;

  @override
  State<AnimatedCockatielSplash> createState() =>
      _AnimatedCockatielSplashState();
}

class _AnimatedCockatielSplashState extends State<AnimatedCockatielSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _flight = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
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

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artworkHeight = math.min(
              constraints.maxHeight * 0.68,
              constraints.maxWidth * 1.12,
            );
            return AnimatedBuilder(
              animation: _flight,
              builder: (context, child) {
                final progress = _flight.value;
                return Column(
                  children: [
                    SizedBox(
                      height: artworkHeight,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.translate(
                            offset: Offset(0, -7 * progress),
                            child: Transform.rotate(
                              angle: (progress - 0.5) * 0.018,
                              child: child,
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _ChordFlightPainter(
                                progress: progress,
                                color: colorScheme.primary,
                                secondaryColor: colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
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
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                );
              },
              child: Semantics(
                label: 'Cockatiel vocal coaching artwork',
                image: true,
                child: Image.asset(
                  key: const ValueKey('cockatiel-splash-artwork'),
                  'assets/images/cockatiel_splash_hero.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChordFlightPainter extends CustomPainter {
  const _ChordFlightPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final notePaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final waveformPaint = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final baseline = size.height * 0.66;
    final waveform = Path();
    for (var index = 0; index <= 28; index++) {
      final x = size.width * index / 28;
      final amplitude = (index % 4 == 0 ? 11 : 5) +
          (math.sin(index * 1.7 + progress * math.pi * 2) * 3);
      final y =
          baseline + math.sin(index * 0.85 + progress * math.pi) * amplitude;
      if (index == 0) {
        waveform.moveTo(x, y);
      } else {
        waveform.lineTo(x, y);
      }
    }
    canvas.drawPath(waveform, waveformPaint);

    final notes = [
      Offset(size.width * 0.18, size.height * (0.24 - progress * 0.04)),
      Offset(size.width * 0.78, size.height * (0.18 + progress * 0.03)),
      Offset(size.width * 0.86, size.height * (0.48 - progress * 0.025)),
    ];
    for (var index = 0; index < notes.length; index++) {
      _drawNote(canvas, notes[index], notePaint, flipped: index.isOdd);
    }
  }

  void _drawNote(Canvas canvas, Offset origin, Paint paint,
      {required bool flipped}) {
    final stemDirection = flipped ? -1.0 : 1.0;
    final stemTop = origin.translate(0.0, -22.0 * stemDirection);
    canvas.drawOval(
      Rect.fromCenter(center: origin, width: 13, height: 9),
      paint,
    );
    canvas.drawLine(origin, stemTop, paint);
    canvas.drawLine(
      stemTop,
      stemTop.translate(10.0 * stemDirection, 7.0 * stemDirection),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChordFlightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
