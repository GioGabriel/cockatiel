import 'dart:math' as math;

import '../../shared/models/session_models.dart';

/// One frame of evidence used by both guided training and karaoke scoring.
class VocalMetricFrame {
  const VocalMetricFrame({
    required this.timestampMs,
    required this.targetId,
    this.targetLabel,
    required this.targetFrequencyHz,
    required this.frequencyHz,
    required this.loudnessDb,
    required this.voiced,
    required this.confidence,
  });

  final int timestampMs;
  final String? targetId;
  final String? targetLabel;
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
    required this.evidence,
  });

  final int sampleCount;
  final double pitchAccuracy;
  final double timingAccuracy;
  final double breathControl;
  final double pitchStability;
  final double vibratoConsistency;
  final double noteTransitionSmoothness;
  final Map<String, dynamic> evidence;

  TrainingAttemptMetricSummary toTrainingAttemptMetricSummary() {
    return TrainingAttemptMetricSummary.voice(
      sampleCount: sampleCount,
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      breathControl: breathControl,
      pitchStability: pitchStability,
      vibratoConsistency: vibratoConsistency,
      noteTransitionSmoothness: noteTransitionSmoothness,
      evidence: evidence,
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
  int _capturedFrameCount = 0;
  int _voicedFrameCount = 0;
  int _targetWindowFrameCount = 0;
  int _targetFrameCount = 0;
  int _lowConfidenceFrameCount = 0;
  int _noTargetFrameCount = 0;
  int _droppedFrameCount = 0;
  int _streamGapCount = 0;
  int _interruptionCount = 0;
  int _voicedRunCount = 0;
  int _transitionCount = 0;
  int _completedTransitionCount = 0;
  int _failedTransitionCount = 0;
  double _weightedTargetFrames = 0;
  double _weightedOnTargetFrames = 0;
  double _weightedPitchScore = 0;
  double _weightedAbsCents = 0;
  double _weightedCents = 0;
  double _weightedCentsSquared = 0;
  double _confidenceWeight = 0;
  double _confidenceTotal = 0;
  double _confidenceSquaredTotal = 0;
  double _loudnessTotal = 0;
  double _loudnessSquaredTotal = 0;
  int _currentVoicedRun = 0;
  int _longestVoicedRun = 0;
  bool _previousWasVoiced = false;
  int? _firstTimestampMs;
  int? _lastTimestampMs;
  int? _previousTimestampMs;
  double? _previousTargetFrequencyHz;
  _PendingTransition? _pendingTransition;
  final List<double> _centsErrors = <double>[];
  final List<int> _centsTimestampsMs = <int>[];
  final List<double> _transitionScores = <double>[];
  final Map<String, _SegmentAccumulator> _segments =
      <String, _SegmentAccumulator>{};

  int get sampleCount => _sampleCount;

  void reset() {
    _sampleCount = 0;
    _capturedFrameCount = 0;
    _voicedFrameCount = 0;
    _targetWindowFrameCount = 0;
    _targetFrameCount = 0;
    _lowConfidenceFrameCount = 0;
    _noTargetFrameCount = 0;
    _droppedFrameCount = 0;
    _streamGapCount = 0;
    _interruptionCount = 0;
    _voicedRunCount = 0;
    _transitionCount = 0;
    _completedTransitionCount = 0;
    _failedTransitionCount = 0;
    _weightedTargetFrames = 0;
    _weightedOnTargetFrames = 0;
    _weightedPitchScore = 0;
    _weightedAbsCents = 0;
    _weightedCents = 0;
    _weightedCentsSquared = 0;
    _confidenceWeight = 0;
    _confidenceTotal = 0;
    _confidenceSquaredTotal = 0;
    _loudnessTotal = 0;
    _loudnessSquaredTotal = 0;
    _currentVoicedRun = 0;
    _longestVoicedRun = 0;
    _previousWasVoiced = false;
    _firstTimestampMs = null;
    _lastTimestampMs = null;
    _previousTimestampMs = null;
    _previousTargetFrequencyHz = null;
    _pendingTransition = null;
    _centsErrors.clear();
    _centsTimestampsMs.clear();
    _transitionScores.clear();
    _segments.clear();
  }

  void addFrame(VocalMetricFrame frame) {
    final previousTimestampMs = _previousTimestampMs;
    if (previousTimestampMs != null) {
      final gapMs = frame.timestampMs - previousTimestampMs;
      if (gapMs > 48) {
        final missingFrames = ((gapMs / 32).round() - 1).clamp(0, 200);
        _sampleCount += missingFrames;
        _droppedFrameCount += missingFrames;
        _streamGapCount += 1;
        _currentVoicedRun = 0;
        _previousWasVoiced = false;
      }
    }
    _previousTimestampMs = frame.timestampMs;
    _firstTimestampMs ??= frame.timestampMs;
    _lastTimestampMs = frame.timestampMs;
    _capturedFrameCount += 1;
    _sampleCount += 1;
    final validConfidence = frame.confidence.isFinite
        ? frame.confidence.clamp(0.0, 1.0).toDouble()
        : 0.0;
    _confidenceTotal += validConfidence;
    _confidenceSquaredTotal += validConfidence * validConfidence;
    if (frame.voiced && validConfidence < minimumConfidence) {
      _lowConfidenceFrameCount += 1;
    }
    final hasVoice = frame.voiced &&
        frame.frequencyHz != null &&
        frame.frequencyHz! > 0 &&
        validConfidence >= minimumConfidence;

    if (hasVoice) {
      if (!_previousWasVoiced) {
        _voicedRunCount += 1;
      }
      _voicedFrameCount += 1;
      _currentVoicedRun += 1;
      _longestVoicedRun = math.max(_longestVoicedRun, _currentVoicedRun);
      _loudnessTotal += frame.loudnessDb;
      _loudnessSquaredTotal += frame.loudnessDb * frame.loudnessDb;
    } else {
      if (_previousWasVoiced) {
        _interruptionCount += 1;
      }
      _currentVoicedRun = 0;
    }
    _previousWasVoiced = hasVoice;

    final targetHz = frame.targetFrequencyHz;
    final hasTarget = targetHz != null && targetHz > 0;
    if (hasTarget) {
      _targetWindowFrameCount += 1;
    } else {
      _noTargetFrameCount += 1;
    }
    final segmentId = frame.targetId?.trim();
    if (segmentId != null && segmentId.isNotEmpty) {
      final segment = _segments.putIfAbsent(
        segmentId,
        () => _SegmentAccumulator(
          segmentId: segmentId,
          label: frame.targetLabel,
        ),
      );
      segment.addFrame(
        timestampMs: frame.timestampMs,
        targetHz: targetHz,
        frequencyHz: frame.frequencyHz,
        hasVoice: hasVoice,
        confidence: validConfidence,
        onTargetToleranceCents: onTargetToleranceCents,
      );
    }
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
    _weightedCents += centsError * confidenceWeight;
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
      _completedTransitionCount += 1;
      _pendingTransition = null;
    } else if (settlingMs > 1200) {
      _transitionScores.add(0);
      _failedTransitionCount += 1;
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

    final vibratoEvidence = _vibratoEvidence(targetCoverage);
    final pitchStability = _roundScore(_stabilityScore(targetCoverage));
    final breathControl = _roundScore(_breathSupportScore(coverage));
    final vibratoConsistency = _roundScore(vibratoEvidence.score);

    final transitionScores = List<double>.from(_transitionScores);
    if (_pendingTransition != null) {
      transitionScores.add(0);
    }
    final transitionScore = transitionScores.isEmpty
        ? 100.0
        : transitionScores.reduce((left, right) => left + right) /
            transitionScores.length;
    final noteTransitionSmoothness = _roundScore(
      transitionScore * (targetCoverage == 0 ? 0 : coverage),
    );

    final confidenceMean =
        _capturedFrameCount == 0 ? 0.0 : _confidenceTotal / _capturedFrameCount;
    final confidenceVariance = _capturedFrameCount == 0
        ? 0.0
        : (_confidenceSquaredTotal / _capturedFrameCount) -
            (confidenceMean * confidenceMean);
    final loudnessMean =
        _voicedFrameCount == 0 ? null : _loudnessTotal / _voicedFrameCount;
    final loudnessVariance = _voicedFrameCount == 0
        ? 0.0
        : (_loudnessSquaredTotal / _voicedFrameCount) -
            ((loudnessMean ?? 0) * (loudnessMean ?? 0));
    final pitchMean =
        _confidenceWeight == 0 ? 0.0 : _weightedCents / _confidenceWeight;
    final pitchVariance = _confidenceWeight == 0
        ? 0.0
        : (_weightedCentsSquared / _confidenceWeight) - (pitchMean * pitchMean);
    final targetWindowCoverage = _sampleCount == 0
        ? 0.0
        : (_targetWindowFrameCount / _sampleCount).clamp(0.0, 1.0).toDouble();
    final onTargetRate = _weightedTargetFrames == 0
        ? 0.0
        : (_weightedOnTargetFrames / _weightedTargetFrames * 100)
            .clamp(0.0, 100.0)
            .toDouble();
    final evidence = <String, dynamic>{
      'duration_ms': math.max(
        0,
        (_lastTimestampMs ?? 0) - (_firstTimestampMs ?? 0),
      ),
      'frame_count': _capturedFrameCount,
      'voiced_frame_count': _voicedFrameCount,
      'target_window_frame_count': _targetWindowFrameCount,
      'target_frame_count': _targetFrameCount,
      'low_confidence_frame_count': _lowConfidenceFrameCount,
      'no_target_frame_count': _noTargetFrameCount,
      'dropped_frame_count': _droppedFrameCount,
      'stream_gap_count': _streamGapCount,
      'voiced_coverage_pct': _roundScore(coverage * 100),
      'target_window_coverage_pct': _roundScore(targetWindowCoverage * 100),
      'target_coverage_pct': _roundScore(targetCoverage * 100),
      'on_target_rate_pct': _roundScore(onTargetRate),
      'mean_confidence': _roundScore(confidenceMean, 3),
      'confidence_stddev':
          _roundScore(math.sqrt(math.max(0, confidenceVariance)), 3),
      'mean_loudness_db':
          loudnessMean == null ? null : _roundNumber(loudnessMean),
      'loudness_stddev_db':
          _roundNumber(math.sqrt(math.max(0, loudnessVariance))),
      'mean_abs_cents': _roundNumber(
        _confidenceWeight == 0 ? 0 : _weightedAbsCents / _confidenceWeight,
      ),
      'p95_abs_cents': _roundNumber(
        _percentile(_centsErrors.map((value) => value.abs()).toList(), 0.95),
      ),
      'pitch_bias_cents': _roundNumber(pitchMean),
      'pitch_stddev_cents': _roundNumber(
        math.sqrt(math.max(0, pitchVariance)),
      ),
      'longest_voiced_run_ms': _longestVoicedRun * 32,
      'voiced_run_count': _voicedRunCount,
      'interruption_count': _interruptionCount,
      'transition_count': _transitionCount,
      'completed_transition_count': _completedTransitionCount,
      'failed_transition_count':
          _failedTransitionCount + (_pendingTransition == null ? 0 : 1),
      'vibrato_detected': vibratoEvidence.detected,
      'vibrato_rate_hz': vibratoEvidence.rateHz,
      'vibrato_amplitude_cents': vibratoEvidence.amplitudeCents,
      'vibrato_regularity_pct': vibratoEvidence.regularityPct,
      'segments': _segments.values.map((segment) => segment.toJson()).toList(),
    };

    return VocalMetricSummary(
      sampleCount: _sampleCount,
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      breathControl: breathControl,
      pitchStability: pitchStability,
      vibratoConsistency: vibratoConsistency,
      noteTransitionSmoothness: noteTransitionSmoothness,
      evidence: evidence,
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
      _transitionCount += 1;
      if (_pendingTransition != null) {
        _transitionScores.add(0);
        _failedTransitionCount += 1;
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
        _failedTransitionCount += 1;
        _pendingTransition = null;
      }
    }
  }

  double _stabilityScore(double targetCoverage) {
    if (_confidenceWeight == 0) {
      return 0;
    }
    final mean = _weightedCents / _confidenceWeight;
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

  _VibratoEvidence _vibratoEvidence(double targetCoverage) {
    if (_centsErrors.length < 20 || _centsTimestampsMs.length < 20) {
      return _VibratoEvidence(score: 70 * targetCoverage);
    }
    final mean = _centsErrors.reduce((left, right) => left + right) /
        _centsErrors.length;
    final centered = _centsErrors.map((value) => value - mean).toList();
    final sorted = List<double>.from(centered)..sort();
    final p10 = sorted[(sorted.length * 0.10).floor()];
    final p90 = sorted[(sorted.length * 0.90).floor()];
    final amplitude = (p90 - p10) / 2;
    if (amplitude < 10) {
      return _VibratoEvidence(score: 70 * targetCoverage);
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
      return _VibratoEvidence(score: 70 * targetCoverage);
    }

    final durationSec =
        (_centsTimestampsMs.last - _centsTimestampsMs.first) / 1000;
    if (durationSec <= 0) {
      return _VibratoEvidence(score: 70 * targetCoverage);
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
    return _VibratoEvidence(
      score: ((70 + (quality * 30)) * targetCoverage).clamp(0, 100).toDouble(),
      detected: true,
      rateHz: rateHz,
      amplitudeCents: amplitude,
      regularityPct: regularity * 100,
    );
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

  double _roundScore(double value, [int decimalPlaces = 2]) {
    final scale = math.pow(10, decimalPlaces).toDouble();
    return (value.clamp(0, 100) * scale).roundToDouble() / scale;
  }

  double _roundNumber(double value, [int decimalPlaces = 2]) {
    final scale = math.pow(10, decimalPlaces).toDouble();
    return (value * scale).roundToDouble() / scale;
  }

  double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return 0;
    }
    values.sort();
    final index =
        ((values.length - 1) * percentile).round().clamp(0, values.length - 1);
    return values[index];
  }
}

class _VibratoEvidence {
  const _VibratoEvidence({
    required this.score,
    this.detected = false,
    this.rateHz,
    this.amplitudeCents,
    this.regularityPct,
  });

  final double score;
  final bool detected;
  final double? rateHz;
  final double? amplitudeCents;
  final double? regularityPct;
}

class _SegmentAccumulator {
  _SegmentAccumulator({required this.segmentId, this.label});

  final String segmentId;
  String? label;
  int? _startMs;
  int? _endMs;
  int _frameCount = 0;
  int _voicedFrameCount = 0;
  int _targetFrameCount = 0;
  int _onTargetFrameCount = 0;
  double _confidenceTotal = 0;
  double _scoreTotal = 0;
  double _absCentsTotal = 0;
  final List<double> _absCents = <double>[];

  void addFrame({
    required int timestampMs,
    required double? targetHz,
    required double? frequencyHz,
    required bool hasVoice,
    required double confidence,
    required double onTargetToleranceCents,
  }) {
    _startMs ??= timestampMs;
    _endMs = timestampMs;
    _frameCount += 1;
    _confidenceTotal += confidence;
    if (!hasVoice) {
      return;
    }
    _voicedFrameCount += 1;
    if (targetHz == null || targetHz <= 0 || frequencyHz == null) {
      return;
    }
    final cents = _centsDifference(frequencyHz, targetHz);
    final absCents = cents.abs();
    _targetFrameCount += 1;
    _onTargetFrameCount += absCents <= onTargetToleranceCents ? 1 : 0;
    _scoreTotal += _frameScore(absCents);
    _absCentsTotal += absCents;
    _absCents.add(absCents);
  }

  Map<String, dynamic> toJson() {
    final targetCoverage = _frameCount == 0
        ? 0.0
        : (_targetFrameCount / _frameCount * 100).clamp(0.0, 100.0).toDouble();
    final voicedCoverage = _frameCount == 0
        ? 0.0
        : (_voicedFrameCount / _frameCount * 100).clamp(0.0, 100.0).toDouble();
    final onTargetRate = _targetFrameCount == 0
        ? 0.0
        : (_onTargetFrameCount / _targetFrameCount * 100)
            .clamp(0.0, 100.0)
            .toDouble();
    final measured = _targetFrameCount > 0;
    return {
      'segment_id': segmentId,
      'label': label,
      'start_ms': _startMs ?? 0,
      'end_ms': _endMs ?? _startMs ?? 0,
      'frame_count': _frameCount,
      'voiced_frame_count': _voicedFrameCount,
      'target_frame_count': _targetFrameCount,
      'voiced_coverage_pct': _roundNumber(voicedCoverage),
      'target_coverage_pct': _roundNumber(targetCoverage),
      'on_target_rate_pct': _roundNumber(onTargetRate),
      'mean_confidence': _roundNumber(
        _frameCount == 0 ? 0 : _confidenceTotal / _frameCount,
        decimalPlaces: 3,
      ),
      'mean_abs_cents': _roundNumber(
        measured ? _absCentsTotal / _targetFrameCount : 0,
      ),
      'p95_abs_cents': _roundNumber(_percentile(_absCents, 0.95)),
      'score': _roundNumber(measured ? _scoreTotal / _targetFrameCount : 0),
      'status': measured
          ? (targetCoverage < 80 ? 'partial' : 'measured')
          : 'not_measurable',
      'reason': measured
          ? '${onTargetRate.round()}% of the confident target frames were on target.'
          : 'No confident target-note frames were captured in this segment.',
    };
  }

  static double _frameScore(double absCents) {
    final normalized = (1 - (absCents / 100)).clamp(0.0, 1.0).toDouble();
    return math.pow(normalized, 1.35).toDouble() * 100;
  }

  static double _centsDifference(double frequencyHz, double targetHz) {
    if (frequencyHz <= 0 || targetHz <= 0) {
      return 0;
    }
    return 1200 * (math.log(frequencyHz / targetHz) / math.ln2);
  }

  static double _roundNumber(double value, {int decimalPlaces = 2}) {
    final scale = math.pow(10, decimalPlaces).toDouble();
    return (value * scale).roundToDouble() / scale;
  }

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = List<double>.from(values)..sort();
    final index =
        ((sorted.length - 1) * percentile).round().clamp(0, sorted.length - 1);
    return sorted[index];
  }
}

class _PendingTransition {
  const _PendingTransition({required this.startTimestampMs});

  final int startTimestampMs;
}
