import 'package:vocal_coach_app/shared/widgets/studio_scaffold.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/audio/pitch/live_pitch_guidance.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/scrollable_action_layout.dart';

typedef WarmupAnalyzerFactory = LiveAudioAnalyzer Function();

/// A movable-do target exposed by the warm-up explorer.
///
/// The label is pedagogical (`Do`, `Re`, ...), while [noteName] and
/// [frequencyHz] make the actual target transparent and keep it tied to the
/// canonical pitch resolver used by the training scorer.
class WarmupNoteTarget {
  const WarmupNoteTarget({
    required this.label,
    required this.noteName,
    required this.frequencyHz,
    required this.scaleDegree,
  });

  final String label;
  final String noteName;
  final double frequencyHz;
  final int scaleDegree;
}

/// Builds the full movable-do octave for the selected key and tonic octave.
///
/// The first five notes are the beginner pentachord foundation. La, Ti, and
/// the repeated high Do remain available for exploration without implying that
/// every beginner drill must use a full octave.
List<WarmupNoteTarget> warmupNoteTargets({
  String tonicKey = 'C',
  int octave = 4,
}) {
  const labels = <String>['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti', 'Do′'];
  final targets = <WarmupNoteTarget>[];
  for (var index = 0; index < labels.length; index++) {
    final frequencyHz = frequencyHzForPitchLabel(
      labels[index],
      key: tonicKey,
      octave: octave,
    );
    if (frequencyHz == null || !frequencyHz.isFinite || frequencyHz <= 0) {
      continue;
    }
    targets.add(
      WarmupNoteTarget(
        label: labels[index],
        noteName: noteLabelForFrequency(frequencyHz),
        frequencyHz: frequencyHz,
        scaleDegree: index == 7 ? 1 : index + 1,
      ),
    );
  }
  return List<WarmupNoteTarget>.unmodifiable(targets);
}

/// Returned when the user leaves the warm-up and proceeds to the drill.
class WarmupNoteSelection {
  const WarmupNoteSelection({
    required this.target,
    required this.tonicKey,
    required this.octave,
    required this.skipped,
    this.detectedFrequencyHz,
    this.confidence = 0,
  });

  final WarmupNoteTarget target;
  final String tonicKey;
  final int octave;
  final bool skipped;
  final double? detectedFrequencyHz;
  final double confidence;
}

class WarmupNoteExplorerPage extends StatefulWidget {
  const WarmupNoteExplorerPage({
    super.key,
    required this.tonicKey,
    required this.octave,
    this.analyzerFactory = _defaultWarmupAnalyzer,
  });

  final String tonicKey;
  final int octave;
  final WarmupAnalyzerFactory analyzerFactory;

  @override
  State<WarmupNoteExplorerPage> createState() => _WarmupNoteExplorerPageState();
}

LiveAudioAnalyzer _defaultWarmupAnalyzer() => LiveAudioAnalyzer();

class _WarmupNoteExplorerPageState extends State<WarmupNoteExplorerPage> {
  static const _quietFloorDb = -50.0;

  late final List<WarmupNoteTarget> _targets;
  late final LiveAudioAnalyzer _analyzer;
  late final LivePitchGuidanceController _guidanceController;
  late final AudioPlayer _referencePlayer;
  StreamSubscription<LiveAudioFrame>? _audioSubscription;
  Timer? _safetyReminderTimer;

  var _selectedTargetIndex = 0;
  var _guidance = const LivePitchGuidance(
    cue: LivePitchCue.startWhenReady,
    centsError: 0,
    confidence: 0,
  );
  double? _detectedFrequencyHz;
  double? _detectedCents;
  String? _detectedNoteLabel;
  var _detectedConfidence = 0.0;
  var _detectedLoudnessDb = -120.0;
  var _isMeasurable = false;
  var _isAudioReady = false;
  var _isClosing = false;
  var _isPlayingReference = false;
  var _showSafetyReminder = false;
  String? _audioError;
  String? _referenceToneError;
  var _audioDisposed = false;
  Future<void>? _audioStartFuture;
  Future<void>? _audioDisposalFuture;

  WarmupNoteTarget get _selectedTarget => _targets[_selectedTargetIndex];

  @override
  void initState() {
    super.initState();
    _targets = warmupNoteTargets(
      tonicKey: widget.tonicKey,
      octave: widget.octave,
    );
    _analyzer = widget.analyzerFactory();
    _guidanceController = LivePitchGuidanceController();
    _referencePlayer = AudioPlayer();
    _audioStartFuture = _startAudio();
    _safetyReminderTimer = Timer(const Duration(seconds: 45), () {
      if (!mounted) return;
      setState(() => _showSafetyReminder = true);
    });
  }

  @override
  void dispose() {
    _safetyReminderTimer?.cancel();
    unawaited(_disposeAudio());
    super.dispose();
  }

  Future<void> _startAudio() async {
    try {
      await _analyzer.start();
      if (!mounted || _isClosing || _audioDisposed) {
        await _analyzer.stop();
        return;
      }
      _audioSubscription = _analyzer.frames.listen(
        _onAudioFrame,
        onError: (Object error, StackTrace trace) {
          if (!mounted || _isClosing || _audioDisposed) return;
          setState(() {
            _isAudioReady = false;
            _audioError = 'Microphone unavailable. You can skip the warm-up.';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isAudioReady = true;
        _audioError = null;
      });
    } catch (_) {
      if (!mounted || _isClosing || _audioDisposed) return;
      setState(() {
        _isAudioReady = false;
        _audioError = 'Microphone unavailable. You can skip the warm-up.';
      });
    }
  }

  void _onAudioFrame(LiveAudioFrame frame) {
    if (!mounted) return;

    final frequencyHz =
        _isUsableFrequency(frame.frequencyHz) ? frame.frequencyHz! : null;
    final loudnessDb = frame.loudnessDb.isFinite ? frame.loudnessDb : -120.0;
    final confidence = frame.confidence.isFinite
        ? frame.confidence.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final clippingRatio =
        frame.clippingRatio != null && frame.clippingRatio!.isFinite
            ? frame.clippingRatio!
            : 0.0;
    final voiced = frame.voiced && frequencyHz != null;
    final centsError = frequencyHz == null
        ? 0.0
        : centsErrorForFrequencies(
            frequencyHz,
            _selectedTarget.frequencyHz,
          );
    final guidance = _guidanceController.update(
      // The shared controller uses this flag to distinguish idle from live
      // guidance. Warm-up is live guidance, but it is never a scored attempt.
      isAttemptRunning: true,
      hasTarget: true,
      voiced: voiced,
      confidence: confidence,
      loudnessDb: loudnessDb,
      centsError: centsError,
      clippingRatio: clippingRatio,
      quietFloorDb: _quietFloorDb,
    );
    final measurable = frequencyHz != null &&
        _guidanceController.lastFrameMeasurable &&
        guidance.cue != LivePitchCue.noClearNote;
    final detectedLabel =
        measurable ? noteLabelForFrequency(frequencyHz) : null;

    setState(() {
      _guidance = guidance;
      _detectedFrequencyHz = measurable ? frequencyHz : null;
      _detectedCents = measurable ? centsError : null;
      _detectedNoteLabel = detectedLabel;
      _detectedConfidence = confidence;
      _detectedLoudnessDb = loudnessDb;
      _isMeasurable = measurable;
    });
  }

  void _selectTarget(int index) {
    if (_isClosing || index == _selectedTargetIndex) return;
    _guidanceController.reset();
    unawaited(_referencePlayer.stop());
    setState(() {
      _selectedTargetIndex = index;
      _guidance = _guidanceController.current;
      _detectedFrequencyHz = null;
      _detectedCents = null;
      _detectedNoteLabel = null;
      _detectedConfidence = 0;
      _isMeasurable = false;
      _isPlayingReference = false;
      _referenceToneError = null;
    });
  }

  Future<void> _playReferenceTone() async {
    if (_isClosing || _isPlayingReference) return;
    setState(() {
      _isPlayingReference = true;
      _referenceToneError = null;
    });
    try {
      await _referencePlayer.stop();
      await _referencePlayer.setAudioSource(
        AudioSource.uri(
          Uri.dataFromBytes(
            _sineWaveWav(_selectedTarget.frequencyHz),
            mimeType: 'audio/wav',
          ),
        ),
      );
      await _referencePlayer.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _referenceToneError =
              'Reference tone is unavailable on this device. The pitch meter still works.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPlayingReference = false);
      }
    }
  }

  Future<void> _finishWarmup({required bool skipped}) async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    final selection = WarmupNoteSelection(
      target: _selectedTarget,
      tonicKey: widget.tonicKey,
      octave: widget.octave,
      skipped: skipped,
      detectedFrequencyHz: _isMeasurable ? _detectedFrequencyHz : null,
      confidence: _isMeasurable ? _detectedConfidence : 0,
    );
    await _disposeAudio();
    if (!mounted) return;
    Navigator.of(context).pop(selection);
  }

  Future<void> _disposeAudio() {
    return _audioDisposalFuture ??= _disposeAudioOnce();
  }

  Future<void> _disposeAudioOnce() async {
    _audioDisposed = true;
    await _audioStartFuture;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _analyzer.dispose();
    await _referencePlayer.dispose();
  }

  String _formatHz(double value) => '${value.toStringAsFixed(1)} Hz';

  String get _guidanceMessage {
    if (!_isAudioReady && _audioError != null) {
      return 'Microphone is unavailable';
    }
    return _guidance.message;
  }

  IconData get _guidanceIcon => switch (_guidance.cue) {
        LivePitchCue.startWhenReady => Icons.mic_none_rounded,
        LivePitchCue.noClearNote => Icons.hearing_rounded,
        LivePitchCue.tooQuiet => Icons.volume_down_rounded,
        LivePitchCue.tooLoud => Icons.volume_up_rounded,
        LivePitchCue.tooLow => Icons.north_rounded,
        LivePitchCue.tooHigh => Icons.south_rounded,
        LivePitchCue.onTarget => Icons.check_circle_outline_rounded,
        LivePitchCue.holdSteady => Icons.pause_circle_outline_rounded,
        LivePitchCue.takeBreath => Icons.air_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    final guidanceColor = switch (_guidance.cue) {
      LivePitchCue.tooLow || LivePitchCue.tooHigh => theme.colorScheme.primary,
      LivePitchCue.onTarget || LivePitchCue.holdSteady => tokens.success,
      LivePitchCue.tooQuiet || LivePitchCue.tooLoud => tokens.warning,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final centsText = _detectedCents == null
        ? null
        : '${_detectedCents! >= 0 ? '+' : '−'}${_detectedCents!.abs().round()} cents';

    return StudioScaffold(
      maxContentWidth: 880,
      appBar: AppBar(title: const Text('Warm up before your drill')),
      body: ScrollableActionLayout(
        content: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warm up & find your starting note',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose any note and hum gently toward the target. Explore as long as you need—there is no warm-up score or pass/fail result.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                _InfoBanner(
                  icon: Icons.safety_check_rounded,
                  color: theme.colorScheme.primary,
                  text:
                      'Use a comfortable volume. Do not shout or force a note. Stop if you feel pain, strain, dizziness, hoarseness, or discomfort.',
                ),
                const SizedBox(height: 22),
                Text(
                  'Choose a note to explore',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start with the five-note foundation, or explore the full octave.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < _targets.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('warmup-note-${_targets[index].label}'),
                            label: Text(_targets[index].label),
                            selected: index == _selectedTargetIndex,
                            onSelected: (_) => _selectTarget(index),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target ${_selectedTarget.label}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedTarget.noteName} · ${_formatHz(_selectedTarget.frequencyHz)} · Key ${widget.tonicKey}${widget.octave}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isClosing ? null : _playReferenceTone,
                        icon: _isPlayingReference
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.volume_up_rounded),
                        label: const Text('Hear target tone'),
                      ),
                      if (_referenceToneError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _referenceToneError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 124,
                        width: double.infinity,
                        child: WarmupPitchMeter(
                          key: const Key('warmup-pitch-meter'),
                          centsError: _detectedCents,
                          measurable: _isMeasurable,
                          accentColor: guidanceColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('warmup-guidance'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: guidanceColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: guidanceColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(_guidanceIcon, color: guidanceColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _guidanceMessage,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (centsText != null)
                              Text(
                                centsText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _detectedNoteLabel == null
                            ? 'Detected: waiting for a measurable fundamental pitch'
                            : 'Detected: $_detectedNoteLabel · ${_formatHz(_detectedFrequencyHz!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_detectedLoudnessDb > -119) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Signal level: ${_detectedLoudnessDb.toStringAsFixed(1)} dB · confidence ${(_detectedConfidence * 100).round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_isMeasurable) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              key: const Key('warmup-stable-match'),
                              size: 18,
                              color: tokens.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Stable match for this target',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      _isAudioReady ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 18,
                      color: _isAudioReady
                          ? tokens.success
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isAudioReady
                            ? 'Microphone active · normal singing volume'
                            : 'Starting microphone…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showSafetyReminder) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(
                    icon: Icons.air_rounded,
                    color: tokens.warning,
                    text:
                        'Take a relaxed breath or choose another note. Warm-up is for comfortable coordination, not for pushing your range.',
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'This estimates fundamental pitch from the microphone. It does not measure airflow, resonance, throat tension, vocal-fold health, or your formal voice type.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No score is recorded during warm-up.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: _audioError == null
            ? null
            : Text(
                _audioError!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
        action: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed:
                  _isClosing ? null : () => _finishWarmup(skipped: false),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start drill'),
            ),
            TextButton(
              onPressed: _isClosing ? null : () => _finishWarmup(skipped: true),
              child: const Text('Skip warm-up'),
            ),
          ],
        ),
      ),
    );
  }
}

class WarmupPitchMeter extends StatelessWidget {
  const WarmupPitchMeter({
    super.key,
    required this.centsError,
    required this.measurable,
    required this.accentColor,
  });

  final double? centsError;
  final bool measurable;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final safeCents = centsError != null && centsError!.isFinite
        ? centsError!.clamp(-100.0, 100.0).toDouble()
        : 0.0;
    final markerAlignment = safeCents / 100;
    final theme = Theme.of(context);

    return Semantics(
      label: measurable
          ? 'Pitch meter, ${safeCents.round()} cents from target'
          : 'Pitch meter waiting for a measurable note',
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _WarmupPitchMeterPainter(
              accentColor: accentColor,
              trackColor: theme.colorScheme.outlineVariant,
              centerColor: theme.colorScheme.onSurface,
            ),
          ),
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(markerAlignment, -0.05),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: measurable ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  key: const Key('warmup-pitch-marker'),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onSurface,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              measurable ? 'Target center' : 'Waiting for your voice',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmupPitchMeterPainter extends CustomPainter {
  const _WarmupPitchMeterPainter({
    required this.accentColor,
    required this.trackColor,
    required this.centerColor,
  });

  final Color accentColor;
  final Color trackColor;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.46;
    const left = 12.0;
    final right = size.width - 12.0;
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, centerY), Offset(right, centerY), trackPaint);

    final centerPaint = Paint()
      ..color = centerColor.withValues(alpha: 0.85)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width / 2, centerY - 28),
      Offset(size.width / 2, centerY + 28),
      centerPaint,
    );

    final tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65)
      ..strokeWidth = 2;
    for (final fraction in <double>[0, 0.25, 0.75, 1]) {
      final x = left + (right - left) * fraction;
      canvas.drawLine(
        Offset(x, centerY - 12),
        Offset(x, centerY + 12),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WarmupPitchMeterPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.centerColor != centerColor;
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List _sineWaveWav(double frequencyHz) {
  const sampleRate = 44100;
  const durationSec = 1.0;
  const amplitude = 0.18;
  final sampleCount = (sampleRate * durationSec).round();
  final bytes = Uint8List(44 + sampleCount * 2);
  final view = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  writeAscii(0, 'RIFF');
  view.setUint32(4, bytes.length - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  view.setUint32(40, sampleCount * 2, Endian.little);

  for (var index = 0; index < sampleCount; index++) {
    final seconds = index / sampleRate;
    final fadeIn = math.min(1.0, seconds / 0.025);
    final fadeOut = math.min(
      1.0,
      (durationSec - seconds) / 0.05,
    );
    final envelope = math.min(fadeIn, fadeOut);
    final sample = math.sin(2 * math.pi * frequencyHz * seconds) *
        amplitude *
        envelope *
        32767;
    view.setInt16(44 + index * 2, sample.round(), Endian.little);
  }
  return bytes;
}

bool _isUsableFrequency(double? frequencyHz) {
  return frequencyHz != null && frequencyHz.isFinite && frequencyHz > 0;
}
