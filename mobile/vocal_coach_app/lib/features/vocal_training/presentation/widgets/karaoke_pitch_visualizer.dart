import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../shared/models/session_models.dart';

/// A single recorded pitch sample.
class PitchPoint {
  final double elapsedSec;
  final double frequencyHz;
  const PitchPoint(this.elapsedSec, this.frequencyHz);
}

/// Yousician-style scrolling pitch visualizer with rainbow note blocks.
///
/// Shows target note blocks scrolling left (colored by pitch height),
/// with the user's live pitch rendered as a glowing orange squiggly line.
/// Also shows a vertical rainbow pitch scale on the left side.
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
    _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                widget.isRunning ? 'Live Pitch' : 'Song Preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.stages.length} notes',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
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
                    primaryColor: theme.colorScheme.primary,
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

/// Maps a normalized pitch position (0=low, 1=high) to a rainbow color.
/// Low = deep red/orange, mid = green, high = violet/purple.
Color _pitchColor(double norm) {
  final hue = (norm * 270).clamp(0.0, 270.0);
  return HSVColor.fromAHSV(1.0, hue, 0.80, 0.90).toColor();
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

  _PitchPainter({
    required this.stages,
    required this.currentElapsedSec,
    required this.pitchHistory,
    required this.minHz,
    required this.maxHz,
    required this.getTargetFrequency,
    required this.isRunning,
    required this.primaryColor,
  });

  static const double _windowSec = 5.0;
  static const double _playheadFraction = 0.28;
  static const double _blockHeight = 28.0;
  static const double _scaleWidth = 36.0;

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
      return size.height - (norm * size.height).clamp(-60.0, size.height + 60.0);
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
      final noteColor = _pitchColor(norm);

      final isPast = isRunning && currentElapsedSec >= stage.endSec;
      final isActive = isRunning &&
          currentElapsedSec >= stage.startSec &&
          currentElapsedSec < stage.endSec;

      final rectL = max(_scaleWidth, startX);
      final rectR = min(size.width, endX);
      if (rectR <= rectL) continue;

      final rect = Rect.fromLTRB(rectL, cy - _blockHeight / 2, rectR, cy + _blockHeight / 2);
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(7));

      if (isActive) {
        canvas.drawRRect(
          rRect,
          Paint()
            ..color = noteColor.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
      }

      final Color fill = isActive
          ? noteColor
          : isPast
              ? noteColor.withValues(alpha: 0.18)
              : noteColor.withValues(alpha: 0.55);

      canvas.drawRRect(rRect, Paint()..color = fill);

      if (!isPast) {
        canvas.drawLine(
          Offset(rect.left + 7, rect.top + 1.5),
          Offset(rect.right - 7, rect.top + 1.5),
          Paint()
            ..color = Colors.white.withValues(alpha: isActive ? 0.6 : 0.20)
            ..strokeWidth = 1.5
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

  void _drawPitchScale(Canvas canvas, Size size, double loMidi, double hiMidi, double midiRange) {
    final scaleRect = Rect.fromLTWH(0, 0, _scaleWidth - 4, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _pitchColor(1.0).withValues(alpha: 0.7),
        _pitchColor(0.67).withValues(alpha: 0.7),
        _pitchColor(0.5).withValues(alpha: 0.7),
        _pitchColor(0.33).withValues(alpha: 0.7),
        _pitchColor(0.0).withValues(alpha: 0.7),
      ],
    ).createShader(scaleRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 0, 6, size.height), const Radius.circular(3)),
      Paint()..shader = gradient,
    );

    const noteNames = ['C', 'D', 'E', 'G', 'A'];
    for (int m = loMidi.ceil(); m <= hiMidi.floor(); m++) {
      final noteName = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'][m % 12];
      if (!noteNames.contains(noteName)) continue;
      final norm = (m - loMidi) / midiRange;
      final y = size.height - norm * size.height;
      if (y < 8 || y > size.height - 8) continue;

      final span = TextSpan(
        text: noteName,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(10, y - tp.height / 2));
    }
  }

  void _drawGrid(Canvas canvas, Size size, double loMidi, double hiMidi, double midiRange, double offsetX) {
    final faint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    final mid = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 0.5;

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
    canvas.drawRect(
      Rect.fromLTWH(x - 2, 0, 4, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.50)
        ..strokeWidth = 1.5,
    );
  }

  void _drawPitchLine(Canvas canvas, Size size, double Function(double) hzToY, double Function(double) secToX) {
    final path = Path();
    bool started = false;
    double? prevSec;

    for (final pt in pitchHistory) {
      if (pt.frequencyHz <= 0) { started = false; prevSec = null; continue; }
      final x = secToX(pt.elapsedSec);
      if (x < _scaleWidth - 4 || x > size.width + 4) { started = false; prevSec = null; continue; }
      final y = hzToY(pt.frequencyHz).clamp(2.0, size.height - 2.0);

      if (!started || (prevSec != null && pt.elapsedSec - prevSec > 0.15)) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
      prevSec = pt.elapsedSec;
    }

    if (!started) return;

    // Orange glow
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFFFA040).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Orange line
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFFFA040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // Dot at current pitch
    final latest = pitchHistory.last;
    if (latest.frequencyHz > 0) {
      final lx = secToX(latest.elapsedSec);
      final ly = hzToY(latest.frequencyHz).clamp(2.0, size.height - 2.0);
      canvas.drawCircle(Offset(lx, ly), 14,
          Paint()..color = const Color(0xFFFFA040).withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(Offset(lx, ly), 5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(lx, ly), 5,
          Paint()..color = const Color(0xFFFFA040).withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  void _drawLabel(Canvas canvas, String text, Rect rect, bool isActive, bool isPast) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: isPast
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: isActive ? 1.0 : 0.88),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    if (tp.width > rect.width - 6) return;
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, rect.top + (rect.height - tp.height) / 2));
  }

  void _drawPreviewHint(Canvas canvas, Size size) {
    final span = TextSpan(
      text: 'Tap "Start Guided Take" to sing',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.28), fontSize: 11, letterSpacing: 0.4),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 18));
  }

  void _drawEmptyHint(Canvas canvas, Size size) {
    final span = TextSpan(
      text: 'No notes loaded',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  static double _hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 69.0 + 12.0 * log(hz / 440.0) / ln2;
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}
