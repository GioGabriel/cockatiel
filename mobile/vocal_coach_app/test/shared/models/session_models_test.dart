import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

void main() {
  group('SessionCreateResponse', () {
    test('fromJson parses correctly', () {
      final json = {'session_id': 'sess_123', 'status': 'created'};
      final response = SessionCreateResponse.fromJson(json);

      expect(response.sessionId, 'sess_123');
      expect(response.status, 'created');
    });
  });

  group('CanonicalMetricFrame', () {
    test('toJson serializes correctly', () {
      final frame = CanonicalMetricFrame(
        sessionId: 'sess_123',
        timestampMs: 1000,
        exerciseType: 'scale',
        pitchAccuracy: 0.95,
        timingAccuracy: 0.90,
        breathControl: 0.85,
        pitchStability: 0.80,
        vibratoConsistency: 0.75,
        noteTransitionSmoothness: 0.70,
      );

      final json = frame.toJson();

      expect(json['session_id'], 'sess_123');
      expect(json['timestamp_ms'], 1000);
      expect(json['exercise_type'], 'scale');
      expect(json['pitch_accuracy'], 0.95);
      expect(json['timing_accuracy'], 0.90);
      expect(json['breath_control'], 0.85);
      expect(json['pitch_stability'], 0.80);
      expect(json['vibrato_consistency'], 0.75);
      expect(json['note_transition_smoothness'], 0.70);
    });
  });

  group('CoachingFeedback', () {
    test('fromJson parses correctly with optional fields', () {
      final json = {
        'session_id': 'sess_123',
        'overall_score': 88.5,
        'strengths': ['Pitch', 'Tone'],
        'improvements': ['Breath'],
        'next_exercises': ['ex1', 'ex2'],
        'model_used': 'gemini-pro',
        'prompt_version': 'v2',
        'latency_ms': 1200,
      };

      final feedback = CoachingFeedback.fromJson(json);

      expect(feedback.sessionId, 'sess_123');
      expect(feedback.overallScore, 88.5);
      expect(feedback.strengths, ['Pitch', 'Tone']);
      expect(feedback.improvements, ['Breath']);
      expect(feedback.nextExercises, ['ex1', 'ex2']);
      expect(feedback.modelUsed, 'gemini-pro');
      expect(feedback.promptVersion, 'v2');
      expect(feedback.latencyMs, 1200);
    });

    test('fromJson parses correctly without optional fields', () {
      final json = {
        'session_id': 'sess_123',
        'overall_score': 88.5,
        'strengths': ['Pitch', 'Tone'],
        'improvements': ['Breath'],
        'next_exercises': ['ex1', 'ex2'],
        'model_used': 'gemini-pro',
      };

      final feedback = CoachingFeedback.fromJson(json);

      expect(feedback.promptVersion, isNull);
      expect(feedback.latencyMs, isNull);
    });
  });
}
