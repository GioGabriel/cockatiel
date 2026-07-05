import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/live_audio_analyzer.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/animations/page_transitions.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/models/training_models.dart';
import '../../../shared/widgets/animated_score_display.dart';
import '../../../shared/widgets/audio_waveform_visualizer.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../ai_feedback_display/presentation/analysis_queue_page.dart';
import '../../ai_feedback_display/presentation/feedback_page.dart';

class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({
    super.key,
    required this.apiClient,
    required this.appState,
    required this.mode,
    required this.exerciseType,
    required this.sessionId,
    this.exerciseName,
    this.exerciseInstructions,
    this.defaultDifficulty,
  });

  final ApiClient apiClient;
  final AppState appState;
  final String mode;
  final String exerciseType;
  final String sessionId;
  final String? exerciseName;
  final List<String>? exerciseInstructions;
  final String? defaultDifficulty;

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage>
    with WidgetsBindingObserver {
  static const List<String> _aiTips = [
    'Tip: Keep your jaw relaxed for cleaner vowel resonance.',
    'Tip: Support with lower ribs, not throat tension.',
    'Tip: Focus on stable airflow before increasing volume.',
    'Tip: Aim to land notes from below for smoother intonation.',
    'Tip: Keep phrases connected; avoid sudden breath drops.',
  ];
  static const Map<String, double> _targetFrequenciesHz = {
    'Do': 261.63,
    'Re': 293.66,
    'Mi': 329.63,
    'Fa': 349.23,
    'Sol': 392.00,
    'La': 440.00,
    'Ti': 493.88,
  };
  static const List<String> _keyOptions = [
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
    'B',
  ];
  static const Map<String, int> _keySemitoneOffsets = {
    'C': 0,
    'C#': 1,
    'D': 2,
    'D#': 3,
    'E': 4,
    'F': 5,
    'F#': 6,
    'G': 7,
    'G#': 8,
    'A': 9,
    'A#': 10,
    'B': 11,
  };
  static const Map<String, int> _solfegeSemitoneOffsets = {
    'Do': 0,
    'Re': 2,
    'Mi': 4,
    'Fa': 5,
    'Sol': 7,
    'La': 9,
    'Ti': 11,
  };
  static const Map<String, int> _defaultDurationSecByDifficulty = {
    'beginner': 30,
    'intermediate': 45,
    'advanced': 60,
  };

  bool _isLoadingSessionMeta = true;
  bool _isSavingAttempt = false;
  bool _isFinalizing = false;
  bool _isAwaitingAI = false;
  int _tipIndex = 0;
  int _loaderTick = 0;
  int _solfegeIndex = 0;
  double _liveFrequencyHz = 261.63;
  double _liveLoudnessDb = -32.0;
  double _livePitchConfidence = 0;
  double _currentCentsError = 0;
  String _detectedNoteLabel = 'Do';
  String _status = 'Prepare your first take.';
  String _microphoneStatus = 'Initializing microphone...';
  String _exerciseName = '';
  String _exerciseObjective = '';
  List<String> _exerciseInstructions = const [];
  List<String> _focusMetrics = const [];
  String _selectedDifficulty = 'beginner';
  String _selectedKey = 'C';
  int _selectedOctave = 4;
  int _attemptDurationSec = 30;
  int _maxAttempts = 3;
  int _secondsRemaining = 0;
  double _loudnessFloorDb = -42;
  bool _isAttemptRunning = false;
  bool _isCalibratingLoudness = false;
  String? _error;
  String? _microphoneError;
  bool _isMicrophoneReady = false;
  TrainingExercise? _exerciseSpec;
  TrainingRuntimePlan? _runtimePlan;
  List<TrainingAttempt> _attempts = const [];
  String? _selectedBestAttemptId;
  double? _bestAttemptScore;
  final LiveAudioAnalyzer _liveAudioAnalyzer = LiveAudioAnalyzer();
  StreamSubscription<LiveAudioFrame>? _liveAudioSubscription;
  Timer? _tipsTimer;
  Timer? _loaderTimer;
  Timer? _attemptTimer;
  Timer? _calibrationTimer;

  int _windowFrameCount = 0;
  int _windowVoicedFrameCount = 0;
  int _windowOnPitchFrameCount = 0;
  int _windowPitchTransitions = 0;
  double _windowAbsCentsTotal = 0;
  double _windowLoudnessTotal = 0;
  double _windowPitchDeltaTotal = 0;
  double? _windowPreviousFrequencyHz;
  int _onTargetFrameStreak = 0;
  int _calibrationFrameCount = 0;
  double _calibrationLoudnessTotal = 0;
  String? _announcedStageId;
  int _breathingCompletedPhaseCount = 0;
  int _breathingInterruptionCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTipsRotation();
    _startLoaderPulse();
    _loadSessionMetadata();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tipsTimer?.cancel();
    _loaderTimer?.cancel();
    _attemptTimer?.cancel();
    _calibrationTimer?.cancel();
    _liveAudioSubscription?.cancel();
    unawaited(_liveAudioAnalyzer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAttemptRunning || !_isBreathingExercise) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _breathingInterruptionCount += 1;
    }
  }

  void _startTipsRotation() {
    _tipsTimer?.cancel();
    _tipsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_isAwaitingAI) {
        return;
      }
      final tips = _queueTips;
      if (tips.isEmpty) {
        return;
      }
      setState(() {
        _tipIndex = (_tipIndex + 1) % tips.length;
      });
    });
  }

  void _startLoaderPulse() {
    _loaderTimer?.cancel();
    _loaderTimer = Timer.periodic(const Duration(milliseconds: 320), (_) {
      if (!mounted || !_isAwaitingAI) {
        return;
      }
      setState(() {
        _loaderTick += 1;
      });
    });
  }

  Future<void> _startMicrophoneAnalysis() async {
    if (!_requiresMicrophone) {
      setState(() {
        _isMicrophoneReady = false;
        _microphoneError = null;
        _microphoneStatus =
            'No microphone needed for this guided breathing drill.';
      });
      return;
    }

    setState(() {
      _microphoneError = null;
      _microphoneStatus = 'Requesting microphone access...';
    });

    try {
      await _liveAudioAnalyzer.start();
      await _liveAudioSubscription?.cancel();
      _liveAudioSubscription = _liveAudioAnalyzer.frames.listen(
        _onLiveAudioFrame,
        onError: (Object error, StackTrace trace) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isMicrophoneReady = false;
            _microphoneError = 'Microphone stream error: $error';
            _microphoneStatus = 'Microphone unavailable';
          });
        },
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isMicrophoneReady = true;
        _microphoneStatus = 'Listening live';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMicrophoneReady = false;
        _microphoneError = error.toString();
        _microphoneStatus = 'Microphone permission required';
      });
    }
  }

  bool get _requiresMicrophone {
    final exerciseSpec = _exerciseSpec;
    if (exerciseSpec != null) {
      return exerciseSpec.requiresMicrophone;
    }
    return widget.exerciseType != 'breath_support_ladder' &&
        widget.exerciseType != 'long_phrase_breathing';
  }

  bool get _isBreathingExercise {
    final exerciseSpec = _exerciseSpec;
    if (exerciseSpec != null) {
      return exerciseSpec.exerciseMode == 'breathing_timer';
    }
    return !_requiresMicrophone;
  }

  void _onLiveAudioFrame(LiveAudioFrame frame) {
    if (!mounted) {
      return;
    }

    final targetHz = _activeTargetFrequency();
    var nextFrequency = _liveFrequencyHz;
    var nextDetectedLabel = _detectedNoteLabel;
    var nextCentsError = _currentCentsError;
    var nextStatus = _microphoneStatus;

    _windowFrameCount += 1;
    _windowLoudnessTotal += frame.loudnessDb;

    if (_isCalibratingLoudness) {
      _calibrationFrameCount += 1;
      _calibrationLoudnessTotal += frame.loudnessDb;
    }

    if (frame.frequencyHz != null && frame.voiced) {
      final frequencyHz = frame.frequencyHz!;
      final centsError = _centsDifference(frequencyHz, targetHz);
      final absCents = centsError.abs();
      final loudEnough = frame.loudnessDb > _loudnessFloorDb;
      final onPitch = absCents <= 30 && loudEnough;

      _windowVoicedFrameCount += 1;
      _windowAbsCentsTotal += absCents;
      if (onPitch) {
        _windowOnPitchFrameCount += 1;
        _onTargetFrameStreak += 1;
      } else {
        _onTargetFrameStreak = 0;
      }

      if (_windowPreviousFrequencyHz != null) {
        _windowPitchDeltaTotal +=
            (frequencyHz - _windowPreviousFrequencyHz!).abs();
        _windowPitchTransitions += 1;
      }
      _windowPreviousFrequencyHz = frequencyHz;

      if (_runtimePlan == null && _onTargetFrameStreak >= 4) {
        _solfegeIndex = (_solfegeIndex + 1) % _targetFrequenciesHz.length;
        _onTargetFrameStreak = 0;
        nextStatus = 'Great lock. Move to ${_activeTargetLabel()}';
      } else if (_runtimePlan != null && onPitch) {
        nextStatus = _activeStageInstruction();
      }

      nextFrequency = frequencyHz;
      nextDetectedLabel = _closestNoteLabel(frequencyHz);
      nextCentsError = centsError;
    } else {
      _onTargetFrameStreak = 0;
      nextStatus = frame.loudnessDb < -50
          ? 'Speak or sing a little louder to start detection.'
          : 'Listening...';
    }

    setState(() {
      _liveLoudnessDb = frame.loudnessDb;
      _liveFrequencyHz = nextFrequency;
      _detectedNoteLabel = nextDetectedLabel;
      _currentCentsError = nextCentsError;
      _livePitchConfidence = frame.confidence;
      _microphoneStatus = nextStatus;
    });
  }

  TrainingAttemptMetricSummary _buildAttemptMetricSummary() {
    if (_isBreathingExercise) {
      final stageCount = (_runtimePlan?.stages.length ?? 3).clamp(1, 12);
      final completedPhaseCount =
          _breathingCompletedPhaseCount.clamp(1, stageCount);
      final phaseCompletionRate =
          ((completedPhaseCount / stageCount) * 100).clamp(0, 100).toDouble();
      final interruptionPenalty =
          (_breathingInterruptionCount * 12).clamp(0, 36).toDouble();
      final paceAdherence =
          (phaseCompletionRate - interruptionPenalty).clamp(0, 100).toDouble();
      final cycleConsistency = (100 -
              (((stageCount - completedPhaseCount) / stageCount) * 55) -
              (interruptionPenalty * 1.1))
          .clamp(0, 100)
          .toDouble();
      final completionRate =
          (100 - (interruptionPenalty * 0.5)).clamp(0, 100).toDouble();

      return TrainingAttemptMetricSummary.breathing(
        sampleCount: max(_attemptDurationSec, 1),
        phaseCompletionRate: phaseCompletionRate,
        paceAdherence: paceAdherence,
        cycleConsistency: cycleConsistency,
        completionRate: completionRate,
        interruptionCount: _breathingInterruptionCount,
      );
    }

    final frameCount = max(_windowFrameCount, 1);
    final voicedFrameCount = max(_windowVoicedFrameCount, 1);
    final avgAbsCents = _windowAbsCentsTotal / voicedFrameCount;
    final avgLoudnessDb = _windowLoudnessTotal / frameCount;
    final onPitchRatio = _windowOnPitchFrameCount / voicedFrameCount;
    final voicedRatio = _windowVoicedFrameCount / frameCount;
    final avgPitchDelta = _windowPitchTransitions > 0
        ? _windowPitchDeltaTotal / _windowPitchTransitions
        : 0;

    final pitchAccuracy = (100 - (avgAbsCents * 1.25)).clamp(0, 100).toDouble();
    final timingAccuracy = (40 + (onPitchRatio * 60)).clamp(0, 100).toDouble();
    final loudnessPenalty = (avgLoudnessDb + 24).abs() * 2.2;
    final breathControl = (100 - loudnessPenalty).clamp(0, 100).toDouble();
    final pitchStability =
        (100 - (avgPitchDelta * 1.5)).clamp(0, 100).toDouble();
    final vibratoConsistency = (55 + (voicedRatio * 45) - (avgPitchDelta * 0.6))
        .clamp(0, 100)
        .toDouble();
    final noteTransitionSmoothness =
        (100 - (avgPitchDelta * 1.2)).clamp(0, 100).toDouble();

    return TrainingAttemptMetricSummary.voice(
      sampleCount: frameCount,
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      breathControl: breathControl,
      pitchStability: pitchStability,
      vibratoConsistency: vibratoConsistency,
      noteTransitionSmoothness: noteTransitionSmoothness,
    );
  }

  void _resetMetricsWindow() {
    _windowFrameCount = 0;
    _windowVoicedFrameCount = 0;
    _windowOnPitchFrameCount = 0;
    _windowPitchTransitions = 0;
    _windowAbsCentsTotal = 0;
    _windowLoudnessTotal = 0;
    _windowPitchDeltaTotal = 0;
    _windowPreviousFrequencyHz = null;
  }

  double _centsDifference(double frequencyHz, double targetHz) {
    if (frequencyHz <= 0 || targetHz <= 0) {
      return 0;
    }
    return 1200 * (log(frequencyHz / targetHz) / ln2);
  }

  String _closestNoteLabel(double frequencyHz) {
    var bestLabel = 'Do';
    var bestDistance = double.infinity;
    for (final label in _targetFrequenciesHz.keys) {
      final cents = _centsDifference(
        frequencyHz,
        _targetFrequencyForLabel(label),
      ).abs();
      if (cents < bestDistance) {
        bestDistance = cents;
        bestLabel = label;
      }
    }
    return bestLabel;
  }

  Future<void> _loadSessionMetadata() async {
    try {
      final session =
          await widget.apiClient.fetchSession(sessionId: widget.sessionId);
      final config = session.trainingConfig;
      final exerciseSpec = session.exerciseSpec;
      final runtimePlan = session.runtimePlan;
      var resolvedName =
          exerciseSpec?.name ?? widget.exerciseName ?? widget.exerciseType;
      var resolvedObjective = exerciseSpec?.objective ?? '';
      var resolvedInstructions = exerciseSpec?.instructions ??
          widget.exerciseInstructions ??
          const <String>[];
      var resolvedFocusMetrics = exerciseSpec?.focusMetrics
              .map((metric) => _displayMetricLabel(
                    metric,
                    exerciseMode: exerciseSpec.exerciseMode,
                  ))
              .toList() ??
          const <String>[];

      if (resolvedInstructions.isEmpty) {
        try {
          final catalog = await widget.apiClient.fetchTrainingCatalog();
          for (final category in catalog.categories) {
            for (final exercise in category.exercises) {
              if (exercise.exerciseId ==
                  (session.exerciseId ?? widget.exerciseType)) {
                resolvedName = exercise.name;
                resolvedObjective = exercise.objective;
                resolvedInstructions = exercise.instructions;
                resolvedFocusMetrics = exercise.focusMetrics
                    .map((metric) => _displayMetricLabel(
                          metric,
                          exerciseMode: exercise.exerciseMode,
                        ))
                    .toList();
                break;
              }
            }
          }
        } catch (_) {
          // Keep fallback values when catalog lookup fails.
        }
      }

      if (!mounted) {
        return;
      }
      final sessionKey = config?.key.toUpperCase();
      final resolvedKey = _keyOptions.contains(sessionKey) ? sessionKey! : 'C';
      final requiresMicrophone = exerciseSpec?.requiresMicrophone ??
          (widget.exerciseType != 'breath_support_ladder' &&
              widget.exerciseType != 'long_phrase_breathing');
      setState(() {
        _exerciseName = resolvedName;
        _exerciseObjective = resolvedObjective;
        _exerciseInstructions = resolvedInstructions;
        _focusMetrics = resolvedFocusMetrics;
        _exerciseSpec = exerciseSpec;
        _runtimePlan = runtimePlan;
        _selectedDifficulty =
            (config?.difficulty ?? widget.defaultDifficulty ?? 'beginner')
                .toLowerCase();
        _selectedKey = resolvedKey;
        _selectedOctave = (config?.octave ?? 4).clamp(2, 6);
        _attemptDurationSec =
            config?.durationSec ?? _durationForDifficulty(_selectedDifficulty);
        _maxAttempts = config?.maxAttempts ?? 3;
        _attempts = session.attempts ?? const [];
        _selectedBestAttemptId = session.selectedBestAttemptId;
        _bestAttemptScore = session.bestAttemptScore;
        _status = requiresMicrophone
            ? 'Prepare your first take.'
            : 'Prepare for your first guided breathing cycle.';
        _isLoadingSessionMeta = false;
      });
      if (_requiresMicrophone) {
        unawaited(_startMicrophoneAnalysis());
      } else {
        setState(() {
          _microphoneStatus =
              'No microphone needed for this guided breathing drill.';
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      final requiresMicrophone =
          widget.exerciseType != 'breath_support_ladder' &&
              widget.exerciseType != 'long_phrase_breathing';
      setState(() {
        _exerciseName = widget.exerciseName ?? widget.exerciseType;
        _exerciseObjective = '';
        _exerciseInstructions = widget.exerciseInstructions ?? const [];
        _focusMetrics = const [];
        _exerciseSpec = null;
        _runtimePlan = null;
        _selectedDifficulty =
            (widget.defaultDifficulty ?? 'beginner').toLowerCase();
        _selectedKey = 'C';
        _selectedOctave = 4;
        _attemptDurationSec = _durationForDifficulty(_selectedDifficulty);
        _maxAttempts = 3;
        _status = requiresMicrophone
            ? 'Prepare your first take.'
            : 'Prepare for your first guided breathing cycle.';
        _isLoadingSessionMeta = false;
      });
      if (_requiresMicrophone) {
        unawaited(_startMicrophoneAnalysis());
      } else {
        setState(() {
          _microphoneStatus =
              'No microphone needed for this guided breathing drill.';
        });
      }
    }
  }

  int _durationForDifficulty(String difficulty) {
    return _defaultDurationSecByDifficulty[difficulty] ??
        _defaultDurationSecByDifficulty['beginner']!;
  }

  bool get _canStartAnotherAttempt {
    return !_isLoadingSessionMeta &&
        !_isAttemptRunning &&
        !_isSavingAttempt &&
        !_isFinalizing &&
        !_isAwaitingAI &&
        _attempts.length < _maxAttempts;
  }

  /// Normalized amplitude (0.0–1.0) for the waveform visualizer.
  /// Maps loudness from the floor to 0 dB into a visual range.
  double get _liveWaveformAmplitude {
    if (!_isMicrophoneReady || _liveLoudnessDb <= _loudnessFloorDb) {
      return 0.0;
    }
    // Map from loudnessFloor..0 dB to 0.0..1.0
    final range = (0.0 - _loudnessFloorDb).abs();
    if (range <= 0) return 0.0;
    return ((_liveLoudnessDb - _loudnessFloorDb) / range).clamp(0.0, 1.0);
  }

  void _startLoudnessCalibration() {
    if (_isCalibratingLoudness || !_isMicrophoneReady || _isAttemptRunning) {
      return;
    }

    setState(() {
      _isCalibratingLoudness = true;
      _calibrationFrameCount = 0;
      _calibrationLoudnessTotal = 0;
      _error = null;
      _status = 'Calibrating loudness floor... sing steadily for 3 seconds.';
    });

    _calibrationTimer?.cancel();
    _calibrationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      if (_calibrationFrameCount < 6) {
        setState(() {
          _isCalibratingLoudness = false;
          _error = 'Calibration failed. Try again with steady voice input.';
        });
        return;
      }

      final averageLoudness =
          _calibrationLoudnessTotal / _calibrationFrameCount;
      final calibratedFloor = (averageLoudness + 8).clamp(-52.0, -28.0);

      setState(() {
        _isCalibratingLoudness = false;
        _loudnessFloorDb = calibratedFloor;
        _status =
            'Calibration complete. Loudness floor set to ${calibratedFloor.toStringAsFixed(1)} dB.';
      });
      unawaited(HapticFeedback.selectionClick());
    });
  }

  Future<void> _startAttempt() async {
    if (!_canStartAnotherAttempt) {
      return;
    }

    setState(() {
      _isAttemptRunning = true;
      _secondsRemaining = _attemptDurationSec;
      _solfegeIndex = 0;
      _breathingCompletedPhaseCount = 1;
      _breathingInterruptionCount = 0;
      _announcedStageId = _runtimePlan?.stages.isNotEmpty == true
          ? _runtimePlan!.stages.first.stageId
          : null;
      _error = null;
      _status =
          '$_attemptNoun ${_attempts.length + 1} running - ${_activeStageTitle()}';
    });
    unawaited(HapticFeedback.lightImpact());
    _resetMetricsWindow();

    _attemptTimer?.cancel();
    _attemptTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _completeAttempt();
        return;
      }
      final nextSecondsRemaining = _secondsRemaining - 1;
      final nextElapsedSec = (_attemptDurationSec - nextSecondsRemaining)
          .clamp(0, _attemptDurationSec);
      final nextStage = _runtimeStageForElapsed(nextElapsedSec);
      final didAdvanceStage =
          nextStage != null && nextStage.stageId != _announcedStageId;

      setState(() {
        _secondsRemaining = nextSecondsRemaining;
        if (didAdvanceStage) {
          if (_isBreathingExercise) {
            _breathingCompletedPhaseCount += 1;
          }
          _announcedStageId = nextStage.stageId;
          _status =
              '$_attemptNoun ${_attempts.length + 1} running - ${nextStage.title}';
        }
      });
      if (didAdvanceStage) {
        unawaited(HapticFeedback.selectionClick());
      }
    });
  }

  Future<void> _completeAttempt() async {
    _attemptTimer?.cancel();
    setState(() {
      _isAttemptRunning = false;
      _isSavingAttempt = true;
      _announcedStageId = null;
      _secondsRemaining = 0;
    });

    try {
      if (!_isBreathingExercise && _windowFrameCount < 4) {
        setState(() {
          _error = 'Need a bit more voice input. $_attemptNoun not saved.';
          _isSavingAttempt = false;
          _status = '$_attemptNoun ended with insufficient audio input.';
        });
        return;
      }

      final saved = await widget.apiClient.saveTrainingAttempt(
        sessionId: widget.sessionId,
        attemptIndex: _attempts.length + 1,
        difficulty: _selectedDifficulty,
        durationSec: _attemptDurationSec,
        metricSummary: _buildAttemptMetricSummary(),
      );

      final updatedAttempts = [..._attempts, saved.attempt]
        ..sort((a, b) => a.attemptIndex.compareTo(b.attemptIndex));

      setState(() {
        _attempts = updatedAttempts;
        _selectedBestAttemptId = saved.selectedBestAttemptId;
        _bestAttemptScore = saved.bestAttemptScore;
        _status =
            '$_attemptNoun ${saved.attempt.attemptIndex} saved. Best score: ${saved.bestAttemptScore.toStringAsFixed(1)}';
      });
      unawaited(HapticFeedback.lightImpact());
      _resetMetricsWindow();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _status = 'Could not save ${_attemptNoun.toLowerCase()}. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAttempt = false;
        });
      }
    }
  }

  Future<void> _finalizeSession() async {
    if (_isAttemptRunning) {
      setState(() {
        _error =
            'Please wait for the running ${_attemptNoun.toLowerCase()} to finish.';
      });
      return;
    }
    if (_attempts.isEmpty) {
      setState(() {
        _error =
            'Complete at least one ${_attemptNoun.toLowerCase()} before finalizing.';
      });
      return;
    }

    setState(() {
      _isFinalizing = true;
      _error = null;
      _status = 'Finalizing session...';
    });

    try {
      final result =
          await widget.apiClient.finalizeSession(sessionId: widget.sessionId);
      if (result.feedback != null) {
        _openFeedback(result.feedback!, result.status);
        return;
      }

      await widget.appState.refreshAIJobs();
      setState(() {
        _isAwaitingAI = true;
        _status =
            'AI analysis queued. You can continue training other exercises.';
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizing = false;
        });
      }
    }
  }

  int get _attemptElapsedSec {
    if (!_isAttemptRunning) {
      return 0;
    }
    return (_attemptDurationSec - _secondsRemaining)
        .clamp(0, _attemptDurationSec);
  }

  TrainingRuntimeStage? _runtimeStageForElapsed(int elapsedSec) {
    final runtimePlan = _runtimePlan;
    if (runtimePlan == null || runtimePlan.stages.isEmpty) {
      return null;
    }
    for (final stage in runtimePlan.stages) {
      if (elapsedSec < stage.endSec) {
        return stage;
      }
    }
    return runtimePlan.stages.last;
  }

  TrainingRuntimeStage? get _activeRuntimeStage {
    return _runtimeStageForElapsed(_attemptElapsedSec);
  }

  int get _activeStageIndex {
    final runtimePlan = _runtimePlan;
    final activeStage = _activeRuntimeStage;
    if (runtimePlan == null || activeStage == null) {
      return -1;
    }
    return runtimePlan.stages.indexWhere(
      (stage) => stage.stageId == activeStage.stageId,
    );
  }

  String _activeTargetLabel() {
    final runtimeStage = _activeRuntimeStage;
    if (runtimeStage != null) {
      return runtimeStage.targetLabel;
    }
    return _targetFrequenciesHz.keys.elementAt(
      _solfegeIndex % _targetFrequenciesHz.length,
    );
  }

  String _activeStageTitle() {
    return _activeRuntimeStage?.title ?? 'Live target';
  }

  String _activeStageInstruction() {
    return _activeRuntimeStage?.instruction ??
        'Stay relaxed, centered, and connected to the target note.';
  }

  double _activeTargetFrequency() {
    return _targetFrequencyForLabel(_activeTargetLabel());
  }

  double _targetFrequencyForLabel(String solfegeLabel) {
    final keyOffset = _keySemitoneOffsets[_selectedKey] ?? 0;
    final scaleOffset = _solfegeSemitoneOffsets[solfegeLabel] ?? 0;
    final tonicMidi = ((_selectedOctave + 1) * 12) + keyOffset;
    final targetMidi = tonicMidi + scaleOffset;
    return 440.0 * pow(2.0, (targetMidi - 69) / 12).toDouble();
  }

  String _liveCoachStatus() {
    if (_isBreathingExercise) {
      if (_isAttemptRunning) {
        return _activeStageInstruction();
      }
      return 'Follow the breathing ring and move with each phase change.';
    }
    if (!_isMicrophoneReady) {
      return _microphoneStatus;
    }
    final coachCues = _exerciseSpec?.coachCues;
    if (!_isAttemptRunning && coachCues != null) {
      return coachCues.ready;
    }
    final absCents = _currentCentsError.abs();
    if (_liveLoudnessDb < _loudnessFloorDb) {
      return coachCues?.tooSoft ?? 'Too soft - support breath a little more.';
    }
    if (absCents <= 30) {
      return coachCues?.onPitch ?? 'On pitch - hold steady!';
    }
    if (_currentCentsError < 0) {
      return coachCues?.lowPitch ?? 'A bit low - lift placement slightly.';
    }
    return coachCues?.highPitch ?? 'A bit high - relax and settle lower.';
  }

  List<String> get _queueTips {
    final exerciseSpec = _exerciseSpec;
    if (exerciseSpec == null || exerciseSpec.focusMetrics.isEmpty) {
      return _aiTips;
    }

    final focusTips = exerciseSpec.focusMetrics.take(3).map((metric) {
      return 'Focus on ${_metricLabel(metric)} when the AI review arrives.';
    }).toList();

    return [
      exerciseSpec.aiFocus,
      ...focusTips,
      'Best-result context is being used for your coaching feedback.',
    ];
  }

  Future<void> _openQueuePage() async {
    await widget.appState.refreshAIJobs();
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisQueuePage(
          appState: widget.appState,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  void _openFeedback(CoachingFeedback feedback, String status) {
    if (!mounted) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pushReplacement(
      resultRevealRoute(
        builder: (_) => FeedbackPage(
          result: FinalizeResponse(
            sessionId: widget.sessionId,
            status: status,
            feedback: feedback,
          ),
        ),
      ),
    );
  }

  bool get _canFinalizeSession {
    return _attempts.isNotEmpty &&
        !_isAttemptRunning &&
        !_isFinalizing &&
        !_isAwaitingAI &&
        !_isSavingAttempt;
  }

  TrainingAttempt? get _bestAttempt {
    if (_attempts.isEmpty) {
      return null;
    }
    final selectedId = _selectedBestAttemptId;
    if (selectedId != null) {
      for (final attempt in _attempts) {
        if (attempt.attemptId == selectedId) {
          return attempt;
        }
      }
    }
    return _attempts.reduce((a, b) => a.score >= b.score ? a : b);
  }

  TrainingAttempt? get _latestAttempt {
    if (_attempts.isEmpty) {
      return null;
    }
    return _attempts.reduce(
      (a, b) => a.attemptIndex >= b.attemptIndex ? a : b,
    );
  }

  String _difficultyLabel(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _displayMetricLabel(String value, {String? exerciseMode}) {
    final normalized = value.replaceAll('_', ' ').trim().toLowerCase();
    if (exerciseMode == 'breathing_timer') {
      switch (normalized) {
        case 'breath control':
          return 'Breath control';
        case 'phase completion rate':
        case 'phase completion':
          return 'Phase completion';
        case 'pace adherence':
        case 'timing accuracy':
          return 'Pace adherence';
        case 'cycle consistency':
          return 'Cycle consistency';
        case 'completion rate':
          return 'Completion rate';
        case 'interruptions':
        case 'interruption count':
          return 'Interruptions';
        case 'pitch stability':
          return 'Breath steadiness';
        case 'note transition smoothness':
          return 'Phase transitions';
        default:
          return _difficultyLabel(normalized);
      }
    }
    return _difficultyLabel(normalized);
  }

  String _metricLabel(String value) {
    return _displayMetricLabel(
      value,
      exerciseMode: _exerciseSpec?.exerciseMode,
    );
  }

  int get _stageCount => _runtimePlan?.stages.length ?? 0;

  String get _currentStepLabel {
    if (_stageCount == 0) {
      return _isBreathingExercise ? 'Guided cycle' : 'Live target';
    }
    return 'Step ${_activeStageIndex + 1} of $_stageCount';
  }

  TrainingRuntimeStage? get _nextRuntimeStage {
    final runtimePlan = _runtimePlan;
    if (runtimePlan == null || runtimePlan.stages.isEmpty) {
      return null;
    }
    final nextIndex = _activeStageIndex + 1;
    if (nextIndex < 0 || nextIndex >= runtimePlan.stages.length) {
      return null;
    }
    return runtimePlan.stages[nextIndex];
  }

  String get _currentActionTitle {
    if (_isBreathingExercise) {
      return _isAttemptRunning
          ? _activeStageTitle()
          : 'Get ready for the first breathing phase';
    }
    return _isAttemptRunning
        ? 'Sing ${_activeTargetLabel()}'
        : 'Start with ${_activeTargetLabel()}';
  }

  String get _currentActionDetail {
    if (_isBreathingExercise) {
      return _activeStageInstruction();
    }
    if (!_isMicrophoneReady) {
      return 'Enable your microphone, then start the guided session. The coach will keep the current note and cue visible.';
    }
    return _activeStageInstruction();
  }

  String? get _nextActionLabel {
    final nextStage = _nextRuntimeStage;
    if (nextStage == null) {
      return null;
    }
    if (_isBreathingExercise) {
      return 'Next phase: ${nextStage.title}';
    }
    return 'Next note: ${nextStage.targetLabel}';
  }

  String get _attemptNoun => _isBreathingExercise ? 'Cycle' : 'Take';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestAttempt = _latestAttempt;
    final attemptProgressValue = _attemptDurationSec <= 0
        ? 0.0
        : (_attemptDurationSec - _secondsRemaining) / _attemptDurationSec;
    final queueTips = _queueTips;
    final exerciseTitle = _exerciseName.isNotEmpty
        ? _exerciseName
        : (widget.exerciseName ?? 'Session In Progress');

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'exercise_title_${widget.exerciseType}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              exerciseTitle,
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [Color(0xFF113A63), Color(0xFF0E7C86)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22113A63),
                  blurRadius: 30,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CoachBadge(
                        label: _isAttemptRunning
                            ? 'Guided ${_attemptNoun.toLowerCase()} live'
                            : 'Ready to train',
                      ),
                      _CoachBadge(label: _currentStepLabel),
                      _CoachBadge(
                        label:
                            '${_difficultyLabel(_selectedDifficulty)} · $_attemptDurationSec sec',
                      ),
                      _CoachBadge(
                        label: _requiresMicrophone
                            ? (_isMicrophoneReady
                                ? 'Mic active'
                                : 'Mic inactive')
                            : 'No microphone needed',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentActionTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _currentActionDetail,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            if (_nextActionLabel != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _nextActionLabel!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      _AttemptCountdownRing(
                        progress: attemptProgressValue.clamp(0.0, 1.0),
                        secondsRemaining: _isAttemptRunning
                            ? _secondsRemaining
                            : _attemptDurationSec,
                        durationSec: _attemptDurationSec,
                        isRunning: _isAttemptRunning,
                        label: _isAttemptRunning
                            ? (_isBreathingExercise ? 'Breathe' : 'Live')
                            : 'Ready',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_requiresMicrophone)
                    Row(
                      children: [
                        Expanded(
                          child: _HeroFocusTile(
                            label: 'Target note',
                            value: _activeTargetLabel(),
                            supporting:
                                '${_activeTargetFrequency().toStringAsFixed(1)} Hz · Key $_selectedKey$_selectedOctave',
                          ),
                        ),
                        if (_nextRuntimeStage != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroFocusTile(
                              label: 'Next note',
                              value: _nextRuntimeStage!.targetLabel,
                              supporting: _nextRuntimeStage!.title,
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _HeroFocusTile(
                            label: 'Current phase',
                            value: _activeStageTitle(),
                            supporting: 'Follow the timer and stay relaxed.',
                          ),
                        ),
                        if (_nextRuntimeStage != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroFocusTile(
                              label: 'Next phase',
                              value: _nextRuntimeStage!.title,
                              supporting: _nextRuntimeStage!.targetLabel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (_runtimePlan != null) ...[
                    const SizedBox(height: 14),
                    _StageStepper(
                      stages: _runtimePlan!.stages,
                      activeStageIndex:
                          _isAttemptRunning ? _activeStageIndex : 0,
                      elapsedSec: _attemptElapsedSec,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    _liveCoachStatus(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_requiresMicrophone && !_isMicrophoneReady) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _startMicrophoneAnalysis,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Enable Microphone'),
                    ),
                  ],
                  if (_requiresMicrophone &&
                      _isMicrophoneReady &&
                      !_isAttemptRunning) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CompactWaveformIndicator(
                            amplitude: _liveWaveformAmplitude,
                            isActive: true,
                            barCount: 24,
                            height: 24.0,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_isAttemptRunning) ...[
                    const SizedBox(height: 14),
                    Text(
                      '$_attemptNoun progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: attemptProgressValue.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    if (_requiresMicrophone) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: AudioWaveformVisualizer(
                          amplitude: _liveWaveformAmplitude,
                          isActive: _isMicrophoneReady,
                          barCount: 32,
                          barWidth: 3.0,
                          barSpacing: 2.0,
                          maxBarHeight: 56.0,
                          minBarHeight: 4.0,
                          activeColor: const Color(0xFF14B8C4),
                          inactiveColor:
                              Colors.white.withValues(alpha: 0.15),
                          glowEnabled: true,
                          glowIntensity: 0.7,
                          style: WaveformStyle.mirrored,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How This Take Works',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  if (_exerciseObjective.isNotEmpty) ...[
                    Text(_exerciseObjective),
                    const SizedBox(height: 12),
                  ],
                  if ((_exerciseSpec?.whatYouDo ?? '').isNotEmpty) ...[
                    Text('What you do', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(_exerciseSpec!.whatYouDo),
                    const SizedBox(height: 12),
                  ],
                  if (_runtimePlan != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _runtimePlan!.summary,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          for (var index = 0;
                              index < _runtimePlan!.stages.length;
                              index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SessionStageTile(
                                index: index + 1,
                                stage: _runtimePlan!.stages[index],
                                isActive: _activeStageIndex == index,
                                isCompleted: _isAttemptRunning &&
                                    _attemptElapsedSec >=
                                        _runtimePlan!.stages[index].endSec,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else if (_exerciseInstructions.isNotEmpty) ...[
                    for (final step in _exerciseInstructions.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('- $step'),
                      ),
                  ],
                  if (_focusMetrics.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Coach listens for',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final metric in _focusMetrics)
                          _CoachMiniChip(label: metric),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Take Controls', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_isLoadingSessionMeta)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 6),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CoachMiniChip(
                          label:
                              '${_attempts.length}/$_maxAttempts ${_attemptNoun.toLowerCase()}s saved',
                        ),
                        _CoachMiniChip(
                          label:
                              '${_difficultyLabel(_selectedDifficulty)} · $_attemptDurationSec sec',
                        ),
                        if (_bestAttempt != null)
                          _CoachMiniChip(
                            label:
                                'Best ${(_bestAttemptScore ?? _bestAttempt!.score).toStringAsFixed(1)}',
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current status',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            )),
                        const SizedBox(height: 6),
                        Text(
                          _status,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (latestAttempt != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latestAttempt.isBest
                                ? 'Latest review · best ${_attemptNoun.toLowerCase()}'
                                : 'Latest review',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          AnimatedScoreDisplay(
                            score: latestAttempt.score.round(),
                            isPersonalBest: latestAttempt.isBest,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_difficultyLabel(latestAttempt.difficulty)} • ${latestAttempt.durationSec}s',
                          ),
                          if (latestAttempt.strongestMetric != null ||
                              latestAttempt.weakestMetric != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Strongest: ${_metricLabel(latestAttempt.strongestMetric ?? '')} • Needs work: ${_metricLabel(latestAttempt.weakestMetric ?? '')}',
                            ),
                          ],
                          if (latestAttempt.passedThreshold != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              latestAttempt.passedThreshold!
                                  ? 'You met this drill\'s target thresholds.'
                                  : 'One more focused take can raise this drill above target.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_isAttemptRunning && _bestAttemptScore != null) ...[
                    const SizedBox(height: 14),
                    GlassCard.dark(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Best: ${_bestAttemptScore!.toStringAsFixed(1)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Beat it!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed:
                            _canStartAnotherAttempt ? _startAttempt : null,
                        child: Text(
                          _isSavingAttempt
                              ? 'Saving ${_attemptNoun.toLowerCase()}...'
                              : (_isAttemptRunning
                                  ? '$_attemptNoun Running...'
                                  : (_attempts.isEmpty
                                      ? 'Start Guided $_attemptNoun'
                                      : (_canStartAnotherAttempt
                                          ? 'Try Another $_attemptNoun'
                                          : 'Max ${_attemptNoun}s Reached'))),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            _canFinalizeSession ? _finalizeSession : null,
                        child: Text(
                          _isFinalizing
                              ? 'Reviewing...'
                              : (_isBreathingExercise
                                  ? 'Review Guided Breathing'
                                  : 'Review My Best Take'),
                        ),
                      ),
                    ],
                  ),
                  if (_attempts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('${_attemptNoun}s so far',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final attempt in _attempts)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: attempt.isBest
                              ? theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.6)
                              : theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$_attemptNoun ${attempt.attemptIndex}: ${attempt.score.toStringAsFixed(1)} • ${_difficultyLabel(attempt.difficulty)}${attempt.isBest ? ' • best ${_attemptNoun.toLowerCase()}' : ''}',
                        ),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_requiresMicrophone) ...[
            const SizedBox(height: 14),
            Card(
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  title:
                      Text('Coach Details', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    _isMicrophoneReady
                        ? 'Live readings are available. Open this only if you want the technical detail.'
                        : _microphoneStatus,
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CoachMiniChip(
                          label: 'Key $_selectedKey$_selectedOctave',
                        ),
                        _CoachMiniChip(
                          label:
                              'Target ${_activeTargetFrequency().toStringAsFixed(1)} Hz',
                        ),
                        _CoachMiniChip(
                          label:
                              'Loudness floor ${_loudnessFloorDb.toStringAsFixed(1)} dB',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Detected ${_liveFrequencyHz.toStringAsFixed(1)} Hz ($_detectedNoteLabel) • Loudness ${_liveLoudnessDb.toStringAsFixed(1)} dB',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cents error ${_currentCentsError.toStringAsFixed(1)} • Confidence ${(_livePitchConfidence * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: ((_liveFrequencyHz - 180) / 360).clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    if (_microphoneError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _microphoneError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (!_isMicrophoneReady)
                      OutlinedButton.icon(
                        onPressed: _startMicrophoneAnalysis,
                        icon: const Icon(Icons.mic_rounded),
                        label: const Text('Enable Microphone'),
                      )
                    else
                      OutlinedButton(
                        onPressed: (_isCalibratingLoudness ||
                                !_isMicrophoneReady ||
                                _isAttemptRunning ||
                                _isSavingAttempt ||
                                _isFinalizing ||
                                _isAwaitingAI)
                            ? null
                            : _startLoudnessCalibration,
                        child: Text(
                          _isCalibratingLoudness
                              ? 'Calibrating...'
                              : 'Calibrate Loudness',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_isAwaitingAI) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Evaluation in Queue',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(3, (index) {
                        final active = ((_loaderTick + index) % 3) == 0;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          margin: const EdgeInsets.only(right: 8),
                          width: active ? 14 : 10,
                          height: active ? 14 : 10,
                          decoration: BoxDecoration(
                            color: active
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary
                                    .withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      queueTips[_tipIndex % queueTips.length],
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonal(
                          onPressed: _openQueuePage,
                          child: const Text('Open AI Queue'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Continue Other Exercises'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachBadge extends StatelessWidget {
  const _CoachBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroFocusTile extends StatelessWidget {
  const _HeroFocusTile({
    required this.label,
    required this.value,
    required this.supporting,
  });

  final String label;
  final String value;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            supporting,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachMiniChip extends StatelessWidget {
  const _CoachMiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SessionStageTile extends StatelessWidget {
  const _SessionStageTile({
    required this.index,
    required this.stage,
    required this.isActive,
    required this.isCompleted,
  });

  final int index;
  final TrainingRuntimeStage stage;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isActive
        ? theme.colorScheme.primaryContainer
        : (isCompleted ? theme.colorScheme.tertiaryContainer : Colors.white);
    final foregroundColor = isActive
        ? theme.colorScheme.onPrimaryContainer
        : (isCompleted
            ? theme.colorScheme.onTertiaryContainer
            : theme.colorScheme.onSurface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stage.title} • ${stage.targetLabel}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stage.instruction,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${stage.durationSec}s',
            style: theme.textTheme.labelMedium?.copyWith(
              color: foregroundColor.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptCountdownRing extends StatefulWidget {
  const _AttemptCountdownRing({
    required this.progress,
    required this.secondsRemaining,
    required this.durationSec,
    required this.isRunning,
    required this.label,
  });

  final double progress;
  final int secondsRemaining;
  final int durationSec;
  final bool isRunning;
  final String label;

  @override
  State<_AttemptCountdownRing> createState() => _AttemptCountdownRingState();
}

class _AttemptCountdownRingState extends State<_AttemptCountdownRing>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(() {
      setState(() {
        _displayedProgress = _animation.value;
      });
    });
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addListener(() {
      setState(() {});
    });

  late Animation<double> _animation = AlwaysStoppedAnimation(widget.progress);
  late final Animation<double> _pulseAnimation = CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeInOut,
  );
  late double _displayedProgress = widget.progress;

  @override
  void initState() {
    super.initState();
    _syncPulseState();
  }

  @override
  void didUpdateWidget(covariant _AttemptCountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.progress - widget.progress).abs() < 0.0001) {
      _syncPulseState();
    } else {
      _animation = Tween<double>(
        begin: _displayedProgress,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
      _syncPulseState();
    }
  }

  void _syncPulseState() {
    if (widget.isRunning) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }
    _pulseController.stop();
    _pulseController.value = 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.isRunning ? _displayedProgress : 0.0;
    final glowStrength = widget.isRunning ? _pulseAnimation.value : 0.0;

    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1 + (glowStrength * 0.06),
            child: Container(
              width: 102,
              height: 102,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: widget.isRunning ? 0.06 : 0.03,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: widget.isRunning
                          ? 0.16 + (glowStrength * 0.14)
                          : 0.04,
                    ),
                    blurRadius: 20 + (glowStrength * 16),
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final scale = Tween<double>(
                      begin: 0.88,
                      end: 1.0,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child: Text(
                    '${widget.secondsRemaining}',
                    key: ValueKey(widget.secondsRemaining),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  widget.isRunning ? 'sec left' : '${widget.durationSec}s',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageStepper extends StatelessWidget {
  const _StageStepper({
    required this.stages,
    required this.activeStageIndex,
    required this.elapsedSec,
  });

  final List<TrainingRuntimeStage> stages;
  final int activeStageIndex;
  final int elapsedSec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Guided steps', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                _StageStepperChip(
                  stage: stages[index],
                  index: index,
                  isActive: activeStageIndex == index,
                  isCompleted: activeStageIndex >= 0 &&
                      elapsedSec >= stages[index].endSec,
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 22,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StageStepperChip extends StatelessWidget {
  const _StageStepperChip({
    required this.stage,
    required this.index,
    required this.isActive,
    required this.isCompleted,
  });

  final TrainingRuntimeStage stage;
  final int index;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isActive
        ? theme.colorScheme.primaryContainer
        : (isCompleted
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest);
    final foregroundColor = isActive
        ? theme.colorScheme.onPrimaryContainer
        : (isCompleted
            ? theme.colorScheme.onTertiaryContainer
            : theme.colorScheme.onSurfaceVariant);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${index + 1}',
            style: theme.textTheme.labelSmall?.copyWith(color: foregroundColor),
          ),
          const SizedBox(height: 4),
          Text(
            stage.title,
            style: theme.textTheme.titleSmall?.copyWith(color: foregroundColor),
          ),
          const SizedBox(height: 2),
          Text(
            '${stage.targetLabel} • ${stage.durationSec}s',
            style: theme.textTheme.bodySmall?.copyWith(color: foregroundColor),
          ),
        ],
      ),
    );
  }
}
