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
        'summary':
            'Your pitch was steady. Keep practicing relaxed breath support.',
        'model_used': 'gemini-pro',
        'prompt_version': 'v2',
        'latency_ms': 1200,
        'detailed_improvements': [
          {
            'metric_key': 'pitch_accuracy',
            'priority': 'high',
            'finding': 'Pitch accuracy needs attention.',
            'evidence': 'Only 42% of target frames were on target.',
            'why_it_matters': 'This makes the melody harder to recognize.',
            'action': 'Match one target note at a time.',
            'practice_plan': 'Repeat the target for 10 seconds.',
          },
        ],
        'score_breakdown': {
          'metric_mode': 'voice',
          'focus_metrics': ['pitch_accuracy', 'timing_accuracy'],
          'metric_scores': {
            'pitch_accuracy': 86.0,
            'timing_accuracy': 78.0,
          },
          'weighted_components': {
            'pitch_accuracy': 25.8,
            'timing_accuracy': 15.6,
          },
          'scoring_version': '2.0',
          'sample_count': 128,
          'evidence_quality': 'reliable',
          'recording_evidence': {
            'frame_count': 128,
            'voiced_coverage_pct': 94.0,
            'target_coverage_pct': 90.0,
          },
          'metric_details': {
            'pitch_accuracy': {
              'status': 'measured',
              'reason': 'Some target notes were missed.',
              'observed_frames': 115,
              'coverage_pct': 90.0,
            },
          },
          'segments': [
            {
              'segment_id': 'stage_2',
              'label': 'Mi',
              'start_ms': 1000,
              'end_ms': 2000,
              'score': 42.0,
              'status': 'measured',
            },
          ],
        },
      };

      final feedback = CoachingFeedback.fromJson(json);

      expect(feedback.sessionId, 'sess_123');
      expect(feedback.overallScore, 88.5);
      expect(feedback.strengths, ['Pitch', 'Tone']);
      expect(feedback.improvements, ['Breath']);
      expect(feedback.nextExercises, ['ex1', 'ex2']);
      expect(feedback.summary,
          'Your pitch was steady. Keep practicing relaxed breath support.');
      expect(feedback.modelUsed, 'gemini-pro');
      expect(feedback.promptVersion, 'v2');
      expect(feedback.latencyMs, 1200);
      expect(feedback.detailedImprovements, hasLength(1));
      expect(feedback.detailedImprovements.first.metricKey, 'pitch_accuracy');
      expect(feedback.scoreBreakdown, isNotNull);
      expect(feedback.scoreBreakdown!.metricScores['pitch_accuracy'], 86.0);
      expect(feedback.scoreBreakdown!.evidenceQuality, 'reliable');
      expect(feedback.scoreBreakdown!.metricDetails['pitch_accuracy']!.status,
          'measured');
      expect(feedback.scoreBreakdown!.segments.first.label, 'Mi');
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
      expect(feedback.summary, isNull);
      expect(feedback.detailedImprovements, isEmpty);
      expect(feedback.scoreBreakdown, isNull);
    });

    test(
        'session feedback derives a breakdown from an older saved best attempt',
        () {
      final session = SessionDetailsResponse.fromJson({
        'session_id': 'session-1',
        'user_id': 'user-1',
        'mode': 'training',
        'exercise_type': 'warmup_pitch',
        'status': 'completed',
        'feedback': {
          'session_id': 'session-1',
          'overall_score': 7,
          'strengths': ['Baseline recorded'],
          'improvements': ['Pitch'],
          'next_exercises': ['Pitch drill'],
          'model_used': 'coaching-logic-engine',
          'prompt_version': 'v1',
          'latency_ms': 10,
        },
        'attempts': [
          {
            'attempt_id': 'attempt-1',
            'attempt_index': 1,
            'difficulty': 'beginner',
            'duration_sec': 20,
            'score': 7,
            'metric_summary': {
              'metric_mode': 'voice',
              'sample_count': 180,
              'pitch_accuracy': 7,
              'timing_accuracy': 19,
              'breath_control': 24,
              'pitch_stability': 18,
              'vibrato_consistency': 12,
              'note_transition_smoothness': 15,
              'overall_score': 7,
            },
            'score_breakdown': {
              'metric_mode': 'voice',
              'focus_metrics': ['pitch_accuracy', 'timing_accuracy'],
              'metric_scores': {'pitch_accuracy': 7},
              'weighted_components': {'pitch_accuracy': 2.1},
              'scoring_version': '2.0',
              'sample_count': 180,
              'evidence_quality': 'reliable',
            },
            'strongest_metric': 'breath_control',
            'weakest_metric': 'pitch_accuracy',
            'passed_threshold': false,
            'saved_at': 1,
            'is_best': true,
          },
        ],
      });

      expect(session.feedbackForDisplay!.scoreBreakdown, isNotNull);
      expect(
          session.feedbackForDisplay!.scoreBreakdown!
              .metricScores['pitch_accuracy'],
          7);
    });
  });

  test('breathing metric summaries preserve phase evidence', () {
    final summary = TrainingAttemptMetricSummary.breathing(
      sampleCount: 30,
      phaseCompletionRate: 75,
      paceAdherence: 64,
      cycleConsistency: 70,
      completionRate: 82,
      interruptionCount: 1,
      evidence: {
        'duration_ms': 30000,
        'phase_count': 4,
        'completed_phase_count': 3,
        'interruption_count': 1,
      },
    );

    final json = summary.toCreateJson();

    expect(json['evidence'], {
      'duration_ms': 30000,
      'phase_count': 4,
      'completed_phase_count': 3,
      'interruption_count': 1,
    });
  });
}
