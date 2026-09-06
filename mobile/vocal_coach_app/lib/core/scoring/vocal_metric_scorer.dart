import 'dart:math' as math;

import '../../shared/models/session_models.dart';

/// One frame of evidence used by both guided training and karaoke scoring.
class VocalMetricFrame {
  const VocalMetricFrame({
    required this.timestampMs,
    required this.targetId,
    required this.targetFrequencyHz,
    required this.frequencyHz,
    required this.loudnessDb,
    required this.voiced,
    required this.confidence,
  });

  final int timestampMs;
  final String? targetId;
  final double? targetFrequencyHz;
  final double? frequencyHz;
  final double loudnessDb;
  final bool voiced;
  final double confidence;
}

class VocalMetricSummary {
  const VocalMetricSummary({
    required this.sampleCount,
    required this.pitchAccuracy,
    required this.timingAccuracy,
    required this.breathControl,
    required this.pitchStability,
    required this.vibratoConsistency,
    required this.noteTransitionSmoothness,
  });

  final int sampleCount;
  final double pitchAccuracy;
  final double timingAccuracy;
  final double breathControl;
  final double pitchStability;
  final double vibratoConsistency;
  final double noteTransitionSmoothness;

  TrainingAttemptMetricSummary toTrainingAttemptMetricSummary() {
    return TrainingAttemptMetricSummary.voice(
      sampleCount: sampleCount,
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      breathControl: breathControl,
      pitchStability: pitchStability,
      vibratoConsistency: vibratoConsistency,
      noteTransitionSmoothness: noteTransitionSmoothness,
    );
  }
}

/// Aggregates timestamped microphone evidence into the canonical six metrics.
///
/// Scores intentionally use observable evidence only. In particular, a
/// missing target guide cannot produce pitch accuracy, and missing voice frames
/// reduce coverage rather than being silently discarded.
class VocalMetricAccumulator {
  VocalMetricAccumulator({
    this.minimumConfidence = 0.45,
    this.onTargetToleranceCents = 50,
  });

  final double minimumConfidence;
  final double onTargetToleranceCents;

  int _sampleCount = 0;
  int _voicedFrameCount = 0;
  int _targetFrameCount = 0;
  double _weightedTargetFrames = 0;
  double _weightedOnTargetFrames = 0;
  double _weightedPitchScore = 0;
  double _weightedAbsCents = 0;
  double _weightedCentsSquared = 0;
  double _confidenceWeight = 0;
  double _loudnessTotal = 0;
  double _loudnessSquaredTotal = 0;
  int _currentVoicedRun = 0;
  int _longestVoicedRun = 0;
  int? _previousTimestampMs;
  double? _previousTargetFrequencyHz;
  _PendingTransition? _pendingTransition;
  final List<double> _centsErrors = <double>[];
  final List<int> _centsTimestampsMs = <int>[];
  final List<double> _transitionScores = <double>[];

  int get sampleCount => _sampleCount;

  void reset() {
    _sampleCount = 0;
    _voicedFrameCount = 0;
    _targetFrameCount = 0;
    _weightedTargetFrames = 0;
    _weightedOnTargetFrames = 0;
    _weightedPitchScore = 0;
    _weightedAbsCents = 0;
    _weightedCentsSquared = 0;
    _confidenceWeight = 0;
    _loudnessTotal = 0;
    _loudnessSquaredTotal = 0;
    _currentVoicedRun = 0;
    _longestVoicedRun = 0;
    _previousTimestampMs = null;
    _previousTargetFrequencyHz = null;
    _pendingTransition = null;
    _centsErrors.clear();
    _centsTimestampsMs.clear();
    _transitionScores.clear();
  }

  void addFrame(VocalMetricFrame frame) {
    final previousTimestampMs = _previousTimestampMs;
    if (previousTimestampMs != null) {
      final gapMs = frame.timestampMs - previousTimestampMs;
      if (gapMs > 48) {
        final missingFrames = ((gapMs / 32).round() - 1).clamp(0, 200);
        _sampleCount += missingFrames;
        _currentVoicedRun = 0;
      }
    }
    _previousTimestampMs = frame.timestampMs;
    _sampleCount += 1;
    final validConfidence = frame.confidence.isFinite
        ? frame.confidence.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final hasVoice = frame.voiced &&
        frame.frequencyHz != null &&
        frame.frequencyHz! > 0 &&
        validConfidence >= minimumConfidence;

    if (hasVoice) {
      _voicedFrameCount += 1;
      _currentVoicedRun += 1;
      _longestVoicedRun = math.max(_longestVoicedRun, _currentVoicedRun);
      _loudnessTotal += frame.loudnessDb;
      _loudnessSquaredTotal += frame.loudnessDb * frame.loudnessDb;
    } else {
      _currentVoicedRun = 0;
    }

    final targetHz = frame.targetFrequencyHz;
    if (targetHz == null || targetHz <= 0) {
      return;
    }
    _recordTargetTransition(
      frame,
      targetFrequencyHz: targetHz,
      hasVoice: hasVoice,
    );

    if (!hasVoice || frame.frequencyHz == null) {
      return;
    }

    final centsError = _centsDifference(frame.frequencyHz!, targetHz);
    final absCents = centsError.abs();
    final confidenceWeight = math.max(validConfidence, 0.05);
    final targetFrameScore = _pitchFrameScore(absCents);

    _targetFrameCount += 1;
    _weightedTargetFrames += confidenceWeight;
    _weightedOnTargetFrames +=
        absCents <= onTargetToleranceCents ? confidenceWeight : 0;
    _weightedPitchScore += targetFrameScore * confidenceWeight;
    _weightedAbsCents += absCents * confidenceWeight;
    _weightedCentsSquared += centsError * centsError * confidenceWeight;
    _confidenceWeight += confidenceWeight;
    _centsErrors.add(centsError);
    _centsTimestampsMs.add(frame.timestampMs);

    final pending = _pendingTransition;
    if (pending == null) {
      return;
    }
    final settlingMs =
        math.max(0, frame.timestampMs - pending.startTimestampMs);
    if (absCents <= onTargetToleranceCents) {
      final landingScore = (100 - (settlingMs * 0.08)).clamp(0, 100);
      final errorScore = _pitchFrameScore(absCents);
      _transitionScores.add((landingScore * 0.6) + (errorScore * 0.4));
      _pendingTransition = null;
    } else if (settlingMs > 1200) {
      _transitionScores.add(0);
      _pendingTransition = null;
    }
  }

  VocalMetricSummary build() {
    final coverage = _sampleCount == 0
        ? 0.0
        : (_voicedFrameCount / _sampleCount).clamp(0.0, 1.0).toDouble();
    final targetCoverage = _sampleCount == 0
        ? 0.0
        : (_targetFrameCount / _sampleCount).clamp(0.0, 1.0).toDouble();

    final targetScore = _confidenceWeight == 0
        ? 0.0
        : (_weightedPitchScore / _confidenceWeight).clamp(0, 100).toDouble();
    final pitchAccuracy = _roundScore(targetScore * targetCoverage);

    final targetAdherence = _weightedTargetFrames == 0
        ? 0.0
        : (_weightedOnTargetFrames / _weightedTargetFrames)
            .clamp(0.0, 1.0)
            .toDouble();
    final timingAccuracy = _roundScore(targetAdherence * targetCoverage * 100);

    final pitchStability = _roundScore(
      _stabilityScore(targetCoverage),
    );
    final breathControl = _roundScore(_breathSupportScore(coverage));
    final vibratoConsistency = _roundScore(
      _vibratoScore(targetCoverage),
    );

    final transitionScore = _transitionScores.isEmpty
        ? 100.0
        : _transitionScores.reduce((left, right) => left + right) /
            _transitionScores.length;
    final noteTransitionSmoothness = _roundScore(
      transitionScore * (targetCoverage == 0 ? 0 : coverage),
    );

    return VocalMetricSummary(
      sampleCount: _sampleCount,
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      breathControl: breathControl,
      pitchStability: pitchStability,
      vibratoConsistency: vibratoConsistency,
      noteTransitionSmoothness: noteTransitionSmoothness,
    );
  }

  void _recordTargetTransition(
    VocalMetricFrame frame, {
    required double targetFrequencyHz,
    required bool hasVoice,
  }) {
    final targetChanged = _previousTargetFrequencyHz != null &&
        _centsDifference(targetFrequencyHz, _previousTargetFrequencyHz!).abs() >
            80;
    if (targetChanged) {
      if (_pendingTransition != null) {
        _transitionScores.add(0);
      }
      _pendingTransition = _PendingTransition(
        startTimestampMs: frame.timestampMs,
      );
    }
    _previousTargetFrequencyHz = targetFrequencyHz;

    if (!hasVoice && _pendingTransition != null) {
      final elapsed = frame.timestampMs - _pendingTransition!.startTimestampMs;
      if (elapsed > 1200) {
        _transitionScores.add(0);
        _pendingTransition = null;
      }
    }
  }

  double _stabilityScore(double targetCoverage) {
    if (_confidenceWeight == 0) {
      return 0;
    }
    final mean = _weightedAbsCents / _confidenceWeight;
    final variance =
        (_weightedCentsSquared / _confidenceWeight) - (mean * mean);
    final standardDeviation = math.sqrt(math.max(0, variance));
    return (math.exp(-standardDeviation / 40) * targetCoverage * 100)
        .clamp(0, 100)
        .toDouble();
  }

  double _breathSupportScore(double coverage) {
    if (_sampleCount == 0 || _voicedFrameCount == 0) {
      return 0;
    }
    final continuity =
        (_longestVoicedRun / _sampleCount).clamp(0.0, 1.0).toDouble();
    final meanLoudness = _loudnessTotal / _voicedFrameCount;
    final loudnessVariance = (_loudnessSquaredTotal / _voicedFrameCount) -
        (meanLoudness * meanLoudness);
    final loudnessStandardDeviation = math.sqrt(math.max(0, loudnessVariance));
    final loudnessConsistency =
        math.exp(-loudnessStandardDeviation / 8).clamp(0.0, 1.0).toDouble();
    return ((coverage * 0.65) +
            (continuity * 0.25) +
            (loudnessConsistency * 0.10)) *
        100;
  }

  double _vibratoScore(double targetCoverage) {
    if (_centsErrors.length < 20 || _centsTimestampsMs.length < 20) {
      return 70 * targetCoverage;
    }
    final mean = _centsErrors.reduce((left, right) => left + right) /
        _centsErrors.length;
    final centered = _centsErrors.map((value) => value - mean).toList();
    final sorted = List<double>.from(centered)..sort();
    final p10 = sorted[(sorted.length * 0.10).floor()];
    final p90 = sorted[(sorted.length * 0.90).floor()];
    final amplitude = (p90 - p10) / 2;
    if (amplitude < 10) {
      return 70 * targetCoverage;
    }

    final crossingTimes = <int>[];
    var previousSign = 0;
    for (var index = 0; index < centered.length; index++) {
      final sign = centered[index] > 0
          ? 1
          : centered[index] < 0
              ? -1
              : 0;
      if (sign == 0) {
        continue;
      }
      if (previousSign != 0 && sign != previousSign) {
        crossingTimes.add(_centsTimestampsMs[index]);
      }
      previousSign = sign;
    }
    if (crossingTimes.length < 4) {
      return 70 * targetCoverage;
    }

    final durationSec =
        (_centsTimestampsMs.last - _centsTimestampsMs.first) / 1000;
    if (durationSec <= 0) {
      return 70 * targetCoverage;
    }
    final rateHz = crossingTimes.length / (2 * durationSec);
    final rateScore =
        (1 - ((rateHz - 5.5).abs() / 3.5)).clamp(0.0, 1.0).toDouble();
    final amplitudeScore =
        (1 - ((amplitude - 55).abs() / 55)).clamp(0.0, 1.0).toDouble();
    final intervals = <double>[];
    for (var index = 1; index < crossingTimes.length; index++) {
      intervals
          .add((crossingTimes[index] - crossingTimes[index - 1]).toDouble());
    }
    final intervalMean =
        intervals.reduce((left, right) => left + right) / intervals.length;
    final intervalVariance = intervals
            .map((value) => math.pow(value - intervalMean, 2).toDouble())
            .reduce((left, right) => left + right) /
        intervals.length;
    final regularity = math.exp(
      -math.sqrt(math.max(0, intervalVariance)) / intervalMean.clamp(1, 10000),
    );

    final quality = rateScore * amplitudeScore * regularity;
    // No observable vibrato is neutral (70), not a failure. Measured,
    // periodic modulation can lift the result above neutral; irregular
    // movement cannot manufacture a high score.
    return ((70 + (quality * 30)) * targetCoverage).clamp(0, 100).toDouble();
  }

  double _pitchFrameScore(double absCents) {
    final normalized = (1 - (absCents / 100)).clamp(0.0, 1.0).toDouble();
    return math.pow(normalized, 1.35).toDouble() * 100;
  }

  double _centsDifference(double frequencyHz, double targetHz) {
    if (frequencyHz <= 0 || targetHz <= 0) {
      return 0;
    }
    return 1200 * (math.log(frequencyHz / targetHz) / math.ln2);
  }

  double _roundScore(double value) {
    return (value.clamp(0, 100) * 100).roundToDouble() / 100;
  }
}

class _PendingTransition {
  const _PendingTransition({required this.startTimestampMs});

  final int startTimestampMs;
}
