import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/pitch/yin_pitch_estimator.dart';

List<int> _sineWave({
  required double frequencyHz,
  int sampleRate = 16000,
  int sampleCount = 4096,
  double amplitude = 0.7,
}) {
  return List<int>.generate(sampleCount, (index) {
    final sample =
        amplitude * math.sin(2 * math.pi * frequencyHz * index / sampleRate);
    return (sample * 32767).round();
  });
}

void main() {
  const estimator = YinPitchEstimator(
    sampleRate: 16000,
    minFrequencyHz: 80,
    maxFrequencyHz: 1000,
  );

  test('tracks a clean vocal fundamental with sub-bin interpolation', () {
    final estimate = estimator.estimate(_sineWave(frequencyHz: 440));

    expect(estimate, isNotNull);
    expect(estimate!.frequencyHz, closeTo(440, 2.0));
    expect(estimate.confidence, greaterThan(0.85));
  });

  test('prefers the fundamental when harmonics are present', () {
    final samples = List<int>.generate(4096, (index) {
      final phase = 2 * math.pi * 220 * index / 16000;
      final sample = 0.62 * math.sin(phase) + 0.24 * math.sin(phase * 2);
      return (sample * 32767).round();
    });

    final estimate = estimator.estimate(samples);

    expect(estimate, isNotNull);
    expect(estimate!.frequencyHz, closeTo(220, 2.0));
  });

  test('tracks representative vocal frequencies across the configured range',
      () {
    for (final frequencyHz in <double>[100, 196, 330, 523, 880]) {
      final estimate = estimator.estimate(
        _sineWave(frequencyHz: frequencyHz),
      );

      expect(estimate, isNotNull, reason: 'missing $frequencyHz Hz estimate');
      expect(estimate!.frequencyHz, closeTo(frequencyHz, 4.0));
    }
  });

  test('rejects silence and very short frames', () {
    expect(estimator.estimate(List<int>.filled(4096, 0)), isNull);
    expect(estimator.estimate(List<int>.filled(16, 0)), isNull);
  });
}
