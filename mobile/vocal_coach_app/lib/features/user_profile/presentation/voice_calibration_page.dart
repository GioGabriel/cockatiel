import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/audio/pitch/voice_type_classifier.dart';
import '../../../shared/widgets/audio_waveform_visualizer.dart';

/// Calibration flow that detects the user's voice type by having them
/// sing a few comfortable notes. The classifier determines soprano/alto/
/// tenor/bass and recommends a starting key and octave.
///
/// Returns a [VoiceTypeResult] via Navigator.pop when the user accepts
/// the detected voice type.
class VoiceCalibrationPage extends StatefulWidget {
  const VoiceCalibrationPage({super.key});

  State<VoiceCalibrationPage> createState() => _VoiceCalibrationPageState();
}

enum _CalibrationPhase { intro, listening, analyzing, result, error }

class _VoiceCalibrationPageState extends State<VoiceCalibrationPage>
    with SingleTickerProviderStateMixin {
  final LiveAudioAnalyzer _analyzer = LiveAudioAnalyzer();
  final VoiceTypeClassifier _classifier = VoiceTypeClassifier();

  StreamSubscription<LiveAudioFrame>? _subscription;
  Timer? _calibrationTimer;
  Timer? _countdownTimer;

  _CalibrationPhase _phase = _CalibrationPhase.intro;
  VoiceTypeResult? _result;
  String? _errorMessage;

  double _currentAmplitude = 0.0;
  int _samplesCollected = 0;
  int _secondsRemaining = 8;
  bool _hasVoiceDetected = false;

  static const int _calibrationDurationSec = 8;
  static const double _loudnessFloor = -48.0;

  void dispose() {
    _subscription?.cancel();
    _calibrationTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_analyzer.dispose());
    super.dispose();
  }

  Future<void> _startCalibration() async {
    setState(() {
      _phase = _CalibrationPhase.listening;
      _secondsRemaining = _calibrationDurationSec;
      _samplesCollected = 0;
      _hasVoiceDetected = false;
      _errorMessage = null;
    });

    try {
      await _analyzer.start();
      _subscription = _analyzer.frames.listen(_onAudioFrame);

      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _secondsRemaining -= 1;
          });
          if (_secondsRemaining <= 0) {
            timer.cancel();
            _finishCalibration();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CalibrationPhase.error;
        _errorMessage = 'Could not access microphone. '
            'Please grant microphone permission and try again.';
      });
    }
  }

  void _onAudioFrame(LiveAudioFrame frame) {
    if (!mounted || _phase != _CalibrationPhase.listening) return;

    final normalizedLoudness = frame.loudnessDb > _loudnessFloor
        ? ((frame.loudnessDb - _loudnessFloor) / (0 - _loudnessFloor))
            .clamp(0.0, 1.0)
        : 0.0;

    setState(() {
      _currentAmplitude = normalizedLoudness;
    });

    // Only add voiced samples above the noise floor.
    if (frame.voiced &&
        frame.frequencyHz != null &&
        frame.loudnessDb > _loudnessFloor) {
      _classifier.addSample(frame.frequencyHz!);
      setState(() {
        _samplesCollected = _classifier.sampleCount;
        _hasVoiceDetected = true;
      });
    }
  }

  Future<void> _finishCalibration() async {
    setState(() {
      _phase = _CalibrationPhase.analyzing;
    });

    await _subscription?.cancel();
    _subscription = null;
    await _analyzer.stop();

    // Brief pause for visual transition.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final result = _classifier.classify();
    if (result == null) {
      setState(() {
        _phase = _CalibrationPhase.error;
        _errorMessage = 'Not enough vocal input detected. '
            'Please try again and sing louder or closer to the microphone.';
      });
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _result = result;
      _phase = _CalibrationPhase.result;
    });
  }

  void _retryCalibration() {
    _classifier.reset();
    _startCalibration();
  }

  void _acceptResult() {
    Navigator.of(context).pop(_result);
  }

  void _skipCalibration() {
    Navigator.of(context).pop(null);
  }

  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Voice Type Detection'),
        actions: [
          if (_phase == _CalibrationPhase.intro ||
              _phase == _CalibrationPhase.error)
            TextButton(
              onPressed: _skipCalibration,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildPhaseContent(theme),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(ThemeData theme) {
    switch (_phase) {
      case _CalibrationPhase.intro:
        return _buildIntro(theme);
      case _CalibrationPhase.listening:
        return _buildListening(theme);
      case _CalibrationPhase.analyzing:
        return _buildAnalyzing(theme);
      case _CalibrationPhase.result:
        return _buildResult(theme);
      case _CalibrationPhase.error:
        return _buildError(theme);
    }
  }

  Widget _buildIntro(ThemeData theme) {
    return Padding(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 48,
              color: theme.colorScheme.primary,
              semanticLabel: 'Microphone',
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Let\'s find your voice type',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Sing a few comfortable notes for 8 seconds. '
            'Don\'t push your limits — just sing naturally in the '
            'middle of your range.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'We\'ll detect whether you\'re a soprano, alto, '
            'tenor, or bass and set up your training accordingly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: _startCalibration,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Singing'),
          ),
        ],
      ),
    );
  }

  Widget _buildListening(ThemeData theme) {
    return Padding(
      key: const ValueKey('listening'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_secondsRemaining',
            style: theme.textTheme.displayLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sing now...',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          Center(
            child: AudioWaveformVisualizer(
              amplitude: _currentAmplitude,
              isActive: true,
              barCount: 36,
              barWidth: 3.5,
              barSpacing: 2.5,
              maxBarHeight: 80.0,
              minBarHeight: 4.0,
              glowEnabled: true,
              glowIntensity: 0.8,
              style: WaveformStyle.mirrored,
            ),
          ),
          const SizedBox(height: 32),
          if (_hasVoiceDetected)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                  semanticLabel: 'Voice detected',
                ),
                const SizedBox(width: 8),
                Text(
                  'Voice detected · $_samplesCollected samples',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            )
          else
            Text(
              'Waiting for voice input...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: 1.0 -
                (_secondsRemaining / _calibrationDurationSec)
                    .clamp(0.0, 1.0),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzing(ThemeData theme) {
    return Center(
      key: const ValueKey('analyzing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your voice...',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    final result = _result!;

    return Padding(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: 40,
              color: theme.colorScheme.primary,
              semanticLabel: 'Music note',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re a',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.label,
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Range: ${result.rangeDescription}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ResultRow(
                    label: 'Recommended key',
                    value: result.recommendedKey,
                    icon: Icons.piano_rounded,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _ResultRow(
                    label: 'Recommended octave',
                    value: result.recommendedOctave.toString(),
                    icon: Icons.tune_rounded,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _ResultRow(
                    label: 'Avg frequency',
                    value:
                        '${result.averageFrequencyHz.toStringAsFixed(1)} Hz',
                    icon: Icons.graphic_eq_rounded,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _acceptResult,
            child: const Text('Use These Settings'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _retryCalibration,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: theme.colorScheme.error,
            semanticLabel: 'Error',
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage ?? 'Something went wrong.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _retryCalibration,
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _skipCalibration,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  final String label;
  final String value;
  final IconData icon;
  final ThemeData theme;

  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
