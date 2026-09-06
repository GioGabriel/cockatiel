import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/scoring/vocal_metric_scorer.dart';

void _addFrames(
  VocalMetricAccumulator accumulator, {
  required int count,
  required double frequencyHz,
  double targetFrequencyHz = 440,
  String targetId = 'target-a',
  double loudnessDb = -24,
  double confidence = 0.95,
  bool voiced = true,
}) {
  for (var index = 0; index < count; index++) {
    accumulator.addFrame(
      VocalMetricFrame(
        timestampMs: index * 32,
        targetId: targetId,
        targetFrequencyHz: targetFrequencyHz,
        frequencyHz: voiced ? frequencyHz : null,
        loudnessDb: loudnessDb,
        voiced: voiced,
        confidence: confidence,
      ),
    );
  }
}

void main() {
  test('gives a clean, sustained target a high and stable score', () {
    final accumulator = VocalMetricAccumulator();
    _addFrames(accumulator, count: 100, frequencyHz: 440);

    final summary = accumulator.build();

    expect(summary.sampleCount, 100);
    expect(summary.pitchAccuracy, greaterThan(97));
    expect(summary.timingAccuracy, greaterThan(97));
    expect(summary.pitchStability, greaterThan(97));
    expect(summary.breathControl, greaterThan(85));
    expect(summary.noteTransitionSmoothness, greaterThan(97));
    expect(summary.evidence['frame_count'], 100);
    expect(summary.evidence['voiced_frame_count'], 100);
    expect(summary.evidence['target_frame_count'], 100);
    expect(summary.evidence['target_coverage_pct'], 100);
    expect(summary.evidence['on_target_rate_pct'], greaterThan(99));
    expect(summary.evidence['segments'], hasLength(1));
  });

  test(
      'penalizes a sustained semitone error instead of treating it as accurate',
      () {
    final accumulator = VocalMetricAccumulator();
    final semitoneHigh = 440 * math.pow(2, 50 / 1200);
    _addFrames(
      accumulator,
      count: 100,
      frequencyHz: semitoneHigh.toDouble(),
    );

    final summary = accumulator.build();

    expect(summary.pitchAccuracy, lessThan(80));
    expect(summary.pitchStability, greaterThan(90));
  });

  test('treats missing voice as missing evidence, not a perfect attempt', () {
    final accumulator = VocalMetricAccumulator();
    _addFrames(accumulator, count: 50, frequencyHz: 440);
    _addFrames(accumulator, count: 50, frequencyHz: 440, voiced: false);

    final summary = accumulator.build();

    expect(summary.pitchAccuracy, lessThan(75));
    expect(summary.timingAccuracy, lessThan(75));
    expect(summary.breathControl, lessThan(75));
  });

  test('does not invent pitch accuracy when no target guide is available', () {
    final accumulator = VocalMetricAccumulator();
    for (var index = 0; index < 40; index++) {
      accumulator.addFrame(
        VocalMetricFrame(
          timestampMs: index * 32,
          targetId: null,
          targetFrequencyHz: null,
          frequencyHz: 440,
          loudnessDb: -24,
          voiced: true,
          confidence: 0.95,
        ),
      );
    }

    final summary = accumulator.build();

    expect(summary.pitchAccuracy, 0);
    expect(summary.timingAccuracy, 0);
    expect(summary.breathControl, greaterThan(85));
    expect(summary.evidence['no_target_frame_count'], 40);
    expect(summary.evidence['target_frame_count'], 0);
    expect(summary.evidence['target_coverage_pct'], 0);
  });

  test('counts a dropped audio-stream gap as missing evidence', () {
    final accumulator = VocalMetricAccumulator();
    _addFrames(accumulator, count: 25, frequencyHz: 440);
    accumulator.addFrame(
      const VocalMetricFrame(
        timestampMs: 2000,
        targetId: 'target-a',
        targetFrequencyHz: 440,
        frequencyHz: 440,
        loudnessDb: -24,
        voiced: true,
        confidence: 0.95,
      ),
    );

    final summary = accumulator.build();

    expect(summary.sampleCount, greaterThan(25));
    expect(summary.pitchAccuracy, lessThan(80));
  });

  test('scores a staged target change using settling evidence', () {
    final accumulator = VocalMetricAccumulator();
    _addFrames(accumulator, count: 30, frequencyHz: 440);
    for (var index = 0; index < 12; index++) {
      final progress = (index + 1) / 12;
      final frequency = 440 + ((523.25 - 440) * progress);
      accumulator.addFrame(
        VocalMetricFrame(
          timestampMs: (30 + index) * 32,
          targetId: 'target-b',
          targetFrequencyHz: 523.25,
          frequencyHz: frequency,
          loudnessDb: -24,
          voiced: true,
          confidence: 0.95,
        ),
      );
    }

    final summary = accumulator.build();

    expect(summary.noteTransitionSmoothness, greaterThan(40));
    expect(summary.noteTransitionSmoothness, lessThan(100));
  });

  test('recognizes regular vibrato without rewarding random pitch movement',
      () {
    final accumulator = VocalMetricAccumulator();
    for (var index = 0; index < 140; index++) {
      final seconds = index * 0.032;
      final cents = 48 * math.sin(2 * math.pi * 5 * seconds);
      final frequency = 440 * math.pow(2, cents / 1200);
      accumulator.addFrame(
        VocalMetricFrame(
          timestampMs: index * 32,
          targetId: 'target-a',
          targetFrequencyHz: 440,
          frequencyHz: frequency.toDouble(),
          loudnessDb: -24,
          voiced: true,
          confidence: 0.95,
        ),
      );
    }

    final summary = accumulator.build();

    expect(summary.vibratoConsistency, greaterThan(75));

    final irregular = VocalMetricAccumulator();
    const jitter = <double>[0, 35, -20, 50, -42, 12, -8, 30];
    for (var index = 0; index < 140; index++) {
      final cents = jitter[index % jitter.length];
      final frequency = 440 * math.pow(2, cents / 1200);
      irregular.addFrame(
        VocalMetricFrame(
          timestampMs: index * 32,
          targetId: 'target-a',
          targetFrequencyHz: 440,
          frequencyHz: frequency.toDouble(),
          loudnessDb: -24,
          voiced: true,
          confidence: 0.95,
        ),
      );
    }

    expect(irregular.build().vibratoConsistency, lessThan(75));
  });
}
