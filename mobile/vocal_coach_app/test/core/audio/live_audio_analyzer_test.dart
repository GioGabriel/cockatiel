import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/live_audio_analyzer.dart';

void main() {
  test('default live detector covers the full practical singing envelope', () {
    expect(defaultLivePitchMinFrequencyHz, 60);
    expect(defaultLivePitchMaxFrequencyHz, 1200);
  });

  test('extracts bounded acoustic evidence from a voiced frame', () {
    const sampleRate = 16000;
    final frame = List<int>.generate(
      2048,
      (index) =>
          (12000 * math.sin(2 * math.pi * 440 * index / sampleRate)).round(),
    );

    final features = AcousticFrameFeatures.fromPcm16(
      frame,
      sampleRate: sampleRate,
    );

    expect(features.zeroCrossingRate, greaterThan(0.04));
    expect(features.zeroCrossingRate, lessThan(0.08));
    expect(features.spectralCentroidHz, greaterThan(300));
    expect(features.spectralCentroidHz, lessThan(800));
    expect(
        features.spectralRolloffHz, greaterThan(features.spectralCentroidHz));
    expect(features.clippingRatio, 0);
  });

  test('reports silence without inventing spectral or clipping evidence', () {
    final features = AcousticFrameFeatures.fromPcm16(
      List<int>.filled(2048, 0),
      sampleRate: 16000,
    );

    expect(features.zeroCrossingRate, 0);
    expect(features.spectralCentroidHz, 0);
    expect(features.spectralRolloffHz, 0);
    expect(features.clippingRatio, 0);
  });

  test('calibrates a bounded gate from a robust ambient-noise percentile', () {
    expect(
      calibratedLoudnessFloorDb(<double>[
        -60,
        -52,
        -50,
        -49,
        -48,
        -10,
        double.nan,
      ]),
      closeTo(-42, 0.001),
    );
    expect(calibratedLoudnessFloorDb(const <double>[]), isNull);
    expect(
      calibratedLoudnessFloorDb([-48], percentile: 1.1),
      isNull,
    );
  });
}
