import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../shared/models/session_models.dart';
import '../../../../app/theme/app_theme_tokens.dart';

/// A single recorded pitch sample.
class PitchPoint {
  final double elapsedSec;
  final double frequencyHz;
  const PitchPoint(this.elapsedSec, this.frequencyHz);
}

/// Yousician-style scrolling pitch visualizer with rainbow note blocks.
///
/// Shows target note blocks scrolling left with a restrained accent palette and
/// the user's live pitch rendered as a high-contrast line.
class KaraokePitchVisualizer extends StatefulWidget {
  const KaraokePitchVisualizer({
    super.key,
    required this.stages,
    required this.currentElapsedSec,
    required this.pitchHistory,
    required this.minHz,
    required this.maxHz,
    required this.getTargetFrequency,
    this.isRunning = false,
  });

  final List<TrainingRuntimeStage> stages;
  final double currentElapsedSec;
  final List<PitchPoint> pitchHistory;
  final double minHz;
  final double maxHz;
  final double Function(String) getTargetFrequency;
  final bool isRunning;

  @override
  State<KaraokePitchVisualizer> createState() => _KaraokePitchVisualizerState();
}

class _KaraokePitchVisualizerState extends State<KaraokePitchVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(hours: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final tokens = theme.appTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isRunning ? tokens.success : primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isRunning ? 'REAL-TIME PITCH TRACKER' : 'SONG PITCH MAP',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${widget.stages.length} TARGET NOTES',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AnimatedBuilder(
                animation: _ticker,
                builder: (context, _) => CustomPaint(
                  painter: _PitchPainter(
                    stages: widget.stages,
                    currentElapsedSec: widget.currentElapsedSec,
                    pitchHistory: widget.pitchHistory,
                    minHz: widget.minHz,
                    maxHz: widget.maxHz,
                    getTargetFrequency: widget.getTargetFrequency,
                    isRunning: widget.isRunning,
                    primaryColor: primaryColor,
                    successColor: tokens.success,
                    raisedSurfaceColor:
                        theme.colorScheme.surfaceContainerHighest,
                    outlineColor: theme.colorScheme.outline,
                    outlineVariantColor: theme.colorScheme.outlineVariant,
                    onSurfaceColor: theme.colorScheme.onSurface,
                    onSurfaceVariantColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keep note blocks within the active theme so color does not become a second
/// competing visual language.
Color _pitchColor(double norm, Color fallback) {
  return fallback.withValues(alpha: 0.55 + (norm.clamp(0.0, 1.0) * 0.35));
}

class _PitchPainter extends CustomPainter {
  final List<TrainingRuntimeStage> stages;
  final double currentElapsedSec;
  final List<PitchPoint> pitchHistory;
  final double minHz;
  final double maxHz;
  final double Function(String) getTargetFrequency;
  final bool isRunning;
  final Color primaryColor;
  final Color successColor;
  final Color raisedSurfaceColor;
  final Color outlineColor;
  final Color outlineVariantColor;
  final Color onSurfaceColor;
  final Color onSurfaceVariantColor;

  _PitchPainter({
    required this.stages,
    required this.currentElapsedSec,
    required this.pitchHistory,
    required this.minHz,
    required this.maxHz,
    required this.getTargetFrequency,
    required this.isRunning,
    required this.primaryColor,
    required this.successColor,
    required this.raisedSurfaceColor,
    required this.outlineColor,
    required this.outlineVariantColor,
    required this.onSurfaceColor,
    required this.onSurfaceVariantColor,
  });

  static const double _windowSec = 8.5;
  static const double _playheadFraction = 0.25;
  static const double _blockHeight = 26.0;
  static const double _scaleWidth = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || stages.isEmpty) {
      _drawEmptyHint(canvas, size);
      return;
    }

    final plotWidth = size.width - _scaleWidth;
    final playheadX = _scaleWidth + plotWidth * _playheadFraction;
    final pxPerSec = plotWidth / _windowSec;

    final allHz = stages.map((s) => getTargetFrequency(s.targetLabel)).toList();
    double loHz = min(minHz, allHz.reduce(min) * 0.80);
    double hiHz = max(maxHz, allHz.reduce(max) * 1.20);
    loHz = loHz.clamp(60.0, 800.0);
    hiHz = hiHz.clamp(80.0, 1200.0);
    if (hiHz <= loHz) hiHz = loHz + 200;

    final loMidi = _hzToMidi(loHz);
    final hiMidi = _hzToMidi(hiHz);
    final midiRange = max(1.0, hiMidi - loMidi);

    double hzToY(double hz) {
      if (hz <= 0) return size.height + 60;
      final midi = _hzToMidi(hz);
      final norm = (midi - loMidi) / midiRange;
      return size.height -
          (norm * size.height).clamp(-60.0, size.height + 60.0);
    }

    double hzToNorm(double hz) {
      if (hz <= 0) return 0;
      final midi = _hzToMidi(hz);
      return ((midi - loMidi) / midiRange).clamp(0.0, 1.0);
    }

    final double refSec = isRunning ? currentElapsedSec : -0.5;
    double secToX(double sec) => playheadX + (sec - refSec) * pxPerSec;

    _drawPitchScale(canvas, size, loMidi, hiMidi, midiRange);
    _drawGrid(canvas, size, loMidi, hiMidi, midiRange, _scaleWidth);

    for (final stage in stages) {
      final startX = secToX(stage.startSec.toDouble());
      final endX = secToX(stage.endSec.toDouble());
      if (endX < _scaleWidth - 8 || startX > size.width + 8) continue;

      final hz = getTargetFrequency(stage.targetLabel);
      final cy = hzToY(hz).clamp(0.0, size.height);
      final norm = hzToNorm(hz);
      final noteColor = _pitchColor(norm, primaryColor);

      final isPast = isRunning && currentElapsedSec >= stage.endSec;
      final isActive = isRunning &&
          currentElapsedSec >= stage.startSec &&
          currentElapsedSec < stage.endSec;

      final rectL = max(_scaleWidth, startX);
      final rectR = min(size.width, endX);
      if (rectR <= rectL) continue;

      final rect = Rect.fromLTRB(
          rectL, cy - _blockHeight / 2, rectR, cy + _blockHeight / 2);
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      final Color fill = isActive
          ? noteColor
          : isPast
              ? noteColor.withValues(alpha: 0.18)
              : noteColor.withValues(alpha: 0.65);

      canvas.drawRRect(rRect, Paint()..color = fill);

      if (!isPast) {
        canvas.drawLine(
          Offset(rect.left + 6, rect.top + 2),
          Offset(rect.right - 6, rect.top + 2),
          Paint()
            ..color = onSurfaceColor.withValues(alpha: isActive ? 0.9 : 0.3)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }

      if (rect.width > 24) {
        _drawLabel(canvas, stage.targetLabel, rect, isActive, isPast);
      }
    }

    _drawPlayhead(canvas, size, playheadX);

    if (isRunning && pitchHistory.length > 1) {
      _drawPitchLine(canvas, size, hzToY, secToX);
    }

    if (!isRunning) {
      _drawPreviewHint(canvas, size);
    }
  }

  void _drawPitchScale(Canvas canvas, Size size, double loMidi, double hiMidi,
      double midiRange) {
    final scaleRect = Rect.fromLTWH(0, 0, _scaleWidth, size.height);
    canvas.drawRect(
      scaleRect,
      Paint()..color = raisedSurfaceColor,
    );

    canvas.drawLine(
      const Offset(_scaleWidth - 1, 0),
      Offset(_scaleWidth - 1, size.height),
      Paint()
        ..color = outlineVariantColor
        ..strokeWidth = 1.0,
    );

    const noteNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    double? lastDrawnY;
    for (int m = loMidi.ceil(); m <= hiMidi.floor(); m++) {
      final noteName = [
        'C',
        'C#',
        'D',
        'D#',
        'E',
        'F',
        'F#',
        'G',
        'G#',
        'A',
        'A#',
        'B'
      ][m % 12];
      if (!noteNames.contains(noteName)) continue;
      final norm = (m - loMidi) / midiRange;
      final y = size.height - norm * size.height;
      if (y < 12 || y > size.height - 12) continue;
      if (lastDrawnY != null && (lastDrawnY - y).abs() < 14) continue;
      lastDrawnY = y;

      canvas.drawLine(
        Offset(_scaleWidth - 5, y),
        Offset(_scaleWidth, y),
        Paint()
          ..color = outlineColor
          ..strokeWidth = 1.5,
      );

      final span = TextSpan(
        text: noteName,
        style: TextStyle(
          color: onSurfaceVariantColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas, Offset((_scaleWidth - 6 - tp.width) / 2, y - tp.height / 2));
    }
  }

  void _drawGrid(Canvas canvas, Size size, double loMidi, double hiMidi,
      double midiRange, double offsetX) {
    final faint = Paint()
      ..color = outlineVariantColor.withValues(alpha: 0.65)
      ..strokeWidth = 0.5;
    final mid = Paint()
      ..color = outlineColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.0;

    for (int m = loMidi.ceil(); m <= hiMidi.floor(); m++) {
      final norm = (m - loMidi) / midiRange;
      final y = size.height - norm * size.height;
      canvas.drawLine(Offset(offsetX, y), Offset(size.width, y), faint);
    }
    for (int m = (loMidi / 12).floor() * 12; m <= hiMidi + 12; m += 12) {
      final norm = (m - loMidi) / midiRange;
      final y = size.height - norm * size.height;
      canvas.drawLine(Offset(offsetX, y), Offset(size.width, y), mid);
    }
  }

  void _drawPlayhead(Canvas canvas, Size size, double x) {
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = onSurfaceColor.withValues(alpha: 0.85)
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(Offset(x, 4), 3, Paint()..color = onSurfaceColor);
    canvas.drawCircle(
        Offset(x, size.height - 4), 3, Paint()..color = onSurfaceColor);
  }

  void _drawPitchLine(Canvas canvas, Size size, double Function(double) hzToY,
      double Function(double) secToX) {
    final path = Path();
    bool started = false;
    double? prevSec;

    for (final pt in pitchHistory) {
      if (pt.frequencyHz <= 0) {
        started = false;
        prevSec = null;
        continue;
      }
      final x = secToX(pt.elapsedSec);
      if (x < _scaleWidth - 4 || x > size.width + 4) {
        started = false;
        prevSec = null;
        continue;
      }
      final y = hzToY(pt.frequencyHz).clamp(4.0, size.height - 4.0);

      if (!started || (prevSec != null && pt.elapsedSec - prevSec > 0.15)) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
      prevSec = pt.elapsedSec;
    }

    if (!started) return;

    canvas.drawPath(
        path,
        Paint()
          ..color = successColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    final latest = pitchHistory.last;
    if (latest.frequencyHz > 0) {
      final lx = secToX(latest.elapsedSec);
      final ly = hzToY(latest.frequencyHz).clamp(4.0, size.height - 4.0);
      canvas.drawCircle(Offset(lx, ly), 7, Paint()..color = successColor);
      canvas.drawCircle(Offset(lx, ly), 3, Paint()..color = onSurfaceColor);
    }
  }

  void _drawLabel(
      Canvas canvas, String text, Rect rect, bool isActive, bool isPast) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: isPast
            ? onSurfaceVariantColor.withValues(alpha: 0.45)
            : onSurfaceColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    if (tp.width > rect.width - 6) return;
    tp.paint(
        canvas,
        Offset(rect.left + (rect.width - tp.width) / 2,
            rect.top + (rect.height - tp.height) / 2));
  }

  void _drawPreviewHint(Canvas canvas, Size size) {
    final span = TextSpan(
      text: 'Tap "Start Guided Take" to sing',
      style: TextStyle(
          color: onSurfaceVariantColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 20));
  }

  void _drawEmptyHint(Canvas canvas, Size size) {
    final span = TextSpan(
      text: 'No notes loaded',
      style: TextStyle(color: onSurfaceVariantColor, fontSize: 12),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  static double _hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 69.0 + 12.0 * log(hz / 440.0) / ln2;
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}
