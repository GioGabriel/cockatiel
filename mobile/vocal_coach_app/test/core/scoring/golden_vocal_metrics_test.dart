import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/scoring/vocal_metric_scorer.dart';

void main() {
  final fixtures = (jsonDecode(
    File('test/fixtures/golden_vocal_metrics_v1.json').readAsStringSync(),
  ) as List<dynamic>);

  test('versioned golden fixtures are deterministic and evidence-aware', () {
    final scores = <String, double>{};
    for (final raw in fixtures) {
      final fixture = raw as Map<String, dynamic>;
      final accumulator = VocalMetricAccumulator();
      final hasTarget = fixture['has_target'] as bool;
      final voiced = fixture['voiced'] as bool;
      final offsetCents = (fixture['offset_cents'] as num).toDouble();
      final frequency = 440 * math.pow(2, offsetCents / 1200);
      for (var index = 0; index < 64; index++) {
        accumulator.addFrame(
          VocalMetricFrame(
            timestampMs: index * 32,
            targetId: hasTarget ? 'golden-target' : null,
            targetFrequencyHz: hasTarget ? 440 : null,
            frequencyHz: voiced ? frequency.toDouble() : null,
            loudnessDb: voiced ? -24 : -58,
            voiced: voiced,
            confidence: voiced ? 0.95 : 0.0,
          ),
        );
      }
      final summary = accumulator.build();
      scores[fixture['id'] as String] = summary.pitchAccuracy;
      expect(summary.sampleCount, 64);
    }

    expect(scores['clean_target'], greaterThan(scores['slightly_flat']!));
    expect(scores['slightly_flat'], greaterThan(scores['quarter_tone_flat']!));
    expect(scores['quarter_tone_flat'], greaterThan(scores['semitone_error']!));
    expect(scores['silence'], 0);
    expect(scores['missing_target'], 0);
  });
}
