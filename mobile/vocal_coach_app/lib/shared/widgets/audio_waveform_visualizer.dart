import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated audio waveform visualizer that displays real-time audio
/// amplitude as glowing vertical bars.
///
/// Feed [amplitude] (normalized 0.0–1.0) on every audio frame to
/// drive the animation. When [isActive] is false, bars settle to a
/// low-energy idle state.
///
/// Inspired by modern music/voice apps that show a responsive
/// waveform during recording to confirm audio input is captured.
class AudioWaveformVisualizer extends StatefulWidget {
  const AudioWaveformVisualizer({
    super.key,
    required this.amplitude,
    this.isActive = true,
    this.barCount = 40,
    this.barWidth = 3.0,
    this.barSpacing = 2.0,
    this.maxBarHeight = 80.0,
    this.minBarHeight = 4.0,
    this.activeColor,
    this.inactiveColor,
    this.glowEnabled = true,
    this.glowIntensity = 0.6,
    this.style = WaveformStyle.bars,
    this.smoothingFactor = 0.3,
  });

  /// Current amplitude value, normalized 0.0–1.0.
  final double amplitude;

  /// Whether the visualizer is actively listening to audio.
  final bool isActive;

  /// Number of bars in the waveform.
  final int barCount;

  /// Width of each bar in logical pixels.
  final double barWidth;

  /// Spacing between bars in logical pixels.
  final double barSpacing;

  /// Maximum height a bar can reach.
  final double maxBarHeight;

  /// Minimum height for idle bars.
  final double minBarHeight;

  /// Color for active (voiced) bars. Defaults to theme primary.
  final Color? activeColor;

  /// Color for inactive (silent) bars.
  final Color? inactiveColor;

  /// Whether to render a glow effect behind bars.
  final bool glowEnabled;

  /// Intensity of the glow (0.0–1.0).
  final double glowIntensity;

  /// Visual style variant.
  final WaveformStyle style;

  /// Smoothing factor for amplitude transitions (0.0=instant, 1.0=frozen).
  final double smoothingFactor;

  State<AudioWaveformVisualizer> createState() =>
      _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _barHeights;
  late List<double> _targetHeights;
  final math.Random _random = math.Random();
  double _smoothedAmplitude = 0.0;

  void initState() {
    super.initState();
    _barHeights = List.filled(widget.barCount, widget.minBarHeight);
    _targetHeights = List.filled(widget.barCount, widget.minBarHeight);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_onTick);
    _controller.repeat();
  }

  void didUpdateWidget(AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.barCount != oldWidget.barCount) {
      _barHeights = List.filled(widget.barCount, widget.minBarHeight);
      _targetHeights = List.filled(widget.barCount, widget.minBarHeight);
    }
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;

    // Smooth the incoming amplitude to avoid jarring jumps.
    final targetAmplitude = widget.isActive ? widget.amplitude : 0.0;
    _smoothedAmplitude = _smoothedAmplitude +
        (targetAmplitude - _smoothedAmplitude) *
            (1.0 - widget.smoothingFactor);

    // Generate target heights based on amplitude with natural variance.
    for (var i = 0; i < widget.barCount; i++) {
      final centerBias = 1.0 -
          (2.0 * (i - widget.barCount / 2).abs() / widget.barCount) * 0.4;
      final noise = 0.7 + _random.nextDouble() * 0.6;
      final rawHeight =
          _smoothedAmplitude * widget.maxBarHeight * centerBias * noise;
      _targetHeights[i] = rawHeight.clamp(
        widget.minBarHeight,
        widget.maxBarHeight,
      );
    }

    // Lerp current heights toward targets for smooth animation.
    const lerpSpeed = 0.25;
    for (var i = 0; i < widget.barCount; i++) {
      _barHeights[i] =
          _barHeights[i] + (_targetHeights[i] - _barHeights[i]) * lerpSpeed;
    }

    setState(() {});
  }

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColor = widget.inactiveColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.2);

    final totalWidth =
        widget.barCount * (widget.barWidth + widget.barSpacing) -
            widget.barSpacing;

    return SizedBox(
      width: totalWidth,
      height: widget.maxBarHeight,
      child: CustomPaint(
        painter: _WaveformPainter(
          barHeights: _barHeights,
          barWidth: widget.barWidth,
          barSpacing: widget.barSpacing,
          maxBarHeight: widget.maxBarHeight,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          amplitude: _smoothedAmplitude,
          glowEnabled: widget.glowEnabled,
          glowIntensity: widget.glowIntensity,
          style: widget.style,
        ),
      ),
    );
  }
}

/// Visual style for the waveform.
enum WaveformStyle {
  /// Classic vertical bars (like equalizer).
  bars,

  /// Rounded pill-shaped bars.
  rounded,

  /// Mirrored bars (symmetric top/bottom).
  mirrored,
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.barHeights,
    required this.barWidth,
    required this.barSpacing,
    required this.maxBarHeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.amplitude,
    required this.glowEnabled,
    required this.glowIntensity,
    required this.style,
  });

  final List<double> barHeights;
  final double barWidth;
  final double barSpacing;
  final double maxBarHeight;
  final Color activeColor;
  final Color inactiveColor;
  final double amplitude;
  final bool glowEnabled;
  final double glowIntensity;
  final WaveformStyle style;

  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    for (var i = 0; i < barHeights.length; i++) {
      final x = i * (barWidth + barSpacing);
      final height = barHeights[i];

      // Interpolate color based on bar height relative to max.
      final intensity = (height / maxBarHeight).clamp(0.0, 1.0);
      final barColor = Color.lerp(inactiveColor, activeColor, intensity)!;

      final paint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      // Glow effect for active bars.
      if (glowEnabled && intensity > 0.3) {
        final glowPaint = Paint()
          ..color = activeColor.withValues(
            alpha: intensity * glowIntensity * 0.4,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

        _drawBar(canvas, x, centerY, height, glowPaint);
      }

      _drawBar(canvas, x, centerY, height, paint);
    }
  }

  void _drawBar(
    Canvas canvas,
    double x,
    double centerY,
    double height,
    Paint paint,
  ) {
    switch (style) {
      case WaveformStyle.bars:
        final top = centerY - height / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top, barWidth, height),
            Radius.circular(barWidth / 2),
          ),
          paint,
        );
      case WaveformStyle.rounded:
        final top = centerY - height / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top, barWidth, height),
            Radius.circular(barWidth),
          ),
          paint,
        );
      case WaveformStyle.mirrored:
        final halfHeight = height / 2;
        // Top half.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, centerY - halfHeight, barWidth, halfHeight),
            Radius.circular(barWidth / 2),
          ),
          paint,
        );
        // Bottom half.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, centerY, barWidth, halfHeight),
            Radius.circular(barWidth / 2),
          ),
          paint,
        );
    }
  }

  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}

/// Compact inline waveform for use in cards, headers, or status bars.
/// Shows fewer bars and takes less vertical space.
class CompactWaveformIndicator extends StatelessWidget {
  const CompactWaveformIndicator({
    super.key,
    required this.amplitude,
    this.isActive = true,
    this.barCount = 20,
    this.height = 32.0,
    this.color,
  });

  final double amplitude;
  final bool isActive;
  final int barCount;
  final double height;
  final Color? color;

  Widget build(BuildContext context) {
    return AudioWaveformVisualizer(
      amplitude: amplitude,
      isActive: isActive,
      barCount: barCount,
      barWidth: 2.5,
      barSpacing: 1.5,
      maxBarHeight: height,
      minBarHeight: 3.0,
      activeColor: color,
      glowEnabled: false,
      style: WaveformStyle.rounded,
    );
  }
}
