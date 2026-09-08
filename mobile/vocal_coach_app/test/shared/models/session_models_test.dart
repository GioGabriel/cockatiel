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
              'target_frequency_hz': 329.63,
              'pitch_stddev_cents': 12.0,
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
      expect(feedback.scoreBreakdown!.segments.first.targetFrequencyHz, 329.63);
      expect(feedback.scoreBreakdown!.segments.first.pitchStddevCents, 12.0);
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

  test('runtime stage parses the canonical target contract', () {
    final stage = TrainingRuntimeStage.fromJson({
      'stage_id': 'stage_mi',
      'title': 'Mi',
      'target_label': 'Mi',
      'instruction': 'Keep the center steady.',
      'duration_sec': 2.5,
      'start_sec': 3.0,
      'end_sec': 5.5,
      'rest_after_sec': 0.75,
      'breath_cue': true,
      'target_type': 'sustained_note',
      'target': {
        'target_id': 'stage_mi',
        'solfege': 'Mi',
        'scale_degree': 3,
        'midi_note': 64,
        'target_frequency_hz': 329.63,
        'key': 'C',
        'octave': 4,
        'start_sec': 3.0,
        'end_sec': 5.5,
        'intended_note_duration_sec': 2.5,
        'rest_after_sec': 0.75,
        'target_type': 'sustained_note',
        'breath_cue': true,
      },
    });

    expect(stage.target.scaleDegree, 3);
    expect(stage.target.midiNote, 64);
    expect(stage.target.frequencyHz, 329.63);
    expect(stage.restAfterSec, 0.75);
    expect(stage.breathCue, isTrue);
  });

  test('training session preserves explicit pace and phrase mode', () {
    final config = TrainingSessionConfig.fromJson({
      'difficulty': 'beginner',
      'key': 'C',
      'octave': 4,
      'target_pattern': 'basic_ladder_short',
      'pace': 'slow',
      'phrase_mode': 'short',
      'duration_sec': 25,
      'max_attempts': 3,
    });

    expect(config.pace, 'slow');
    expect(config.phraseMode, 'short');
    expect(config.targetPattern, 'basic_ladder_short');
  });

  test('score status distinguishes unavailable evidence from a measured result',
      () {
    final breakdown = FeedbackScoreBreakdown.fromJson({
      'metric_mode': 'voice',
      'focus_metrics': ['pitch_accuracy'],
      'metric_scores': {'pitch_accuracy': 0.0},
      'weighted_components': {'pitch_accuracy': 0.0},
      'scoring_version': '2.2',
      'sample_count': 64,
      'evidence_quality': 'reliable',
      'score_status': 'not_scorable',
      'recording_evidence': {'target_frame_count': 0},
    });

    expect(breakdown.scoreStatus, 'not_scorable');
  });

  test('voice metric summaries normalize missing and nullable cents evidence',
      () {
    final summary = TrainingAttemptMetricSummary.voice(
      sampleCount: 24,
      pitchAccuracy: 72,
      timingAccuracy: 68,
      breathControl: 75,
      pitchStability: 70,
      vibratoConsistency: 60,
      noteTransitionSmoothness: 66,
      evidence: {
        'p95_abs_cents': null,
        'segments': [
          {'segment_id': 'stage_1', 'p95_abs_cents': null},
          {
            'segment_id': 'stage_2',
            'mean_abs_cents': null,
            'p95_abs_cents': 84.5
          },
          {'segment_id': 'stage_3'},
        ],
      },
    );

    final evidence = summary.toCreateJson()['evidence'] as Map<String, dynamic>;
    final segments = evidence['segments'] as List<dynamic>;

    expect(evidence['mean_abs_cents'], 0.0);
    expect(evidence['p95_abs_cents'], 0.0);
    expect((segments[0] as Map<String, dynamic>)['mean_abs_cents'], 0.0);
    expect((segments[0] as Map<String, dynamic>)['p95_abs_cents'], 0.0);
    expect((segments[1] as Map<String, dynamic>)['mean_abs_cents'], 0.0);
    expect((segments[1] as Map<String, dynamic>)['p95_abs_cents'], 84.5);
    expect((segments[2] as Map<String, dynamic>)['mean_abs_cents'], 0.0);
    expect((segments[2] as Map<String, dynamic>)['p95_abs_cents'], 0.0);
  });

  test(
      'voice metric requests remain compatible with the deployed segment schema',
      () {
    final summary = TrainingAttemptMetricSummary.voice(
      sampleCount: 24,
      pitchAccuracy: 72,
      timingAccuracy: 68,
      breathControl: 75,
      pitchStability: 70,
      vibratoConsistency: 60,
      noteTransitionSmoothness: 66,
      evidence: {
        'p95_abs_cents': 84.5,
        'mean_abs_cents': 42.0,
        'pitch_bias_cents': -12.0,
        'segments': [
          {
            'segment_id': 'stage_1',
            'label': 'Mi',
            'start_ms': 0,
            'end_ms': 2000,
            'frame_count': 24,
            'voiced_frame_count': 20,
            'target_frame_count': 20,
            'voiced_coverage_pct': 83.3,
            'target_coverage_pct': 83.3,
            'on_target_rate_pct': 60,
            'mean_confidence': 0.9,
            'mean_abs_cents': 42,
            'p95_abs_cents': 84.5,
            'target_frequency_hz': 329.63,
            'pitch_stddev_cents': 18,
            'pitch_bias_cents': -12,
            'interrupted': true,
            'recommendation': 'Repeat Mi more gently.',
            'score': 60,
            'status': 'partial',
            'reason': 'The segment was interrupted.',
          },
        ],
      },
    );

    final evidence = summary.toCreateJson()['evidence'] as Map<String, dynamic>;
    final segment =
        (evidence['segments'] as List<dynamic>).single as Map<String, dynamic>;

    expect(segment['segment_id'], 'stage_1');
    expect(segment['mean_abs_cents'], 42.0);
    expect(segment['p95_abs_cents'], 84.5);
    expect(segment.containsKey('target_frequency_hz'), isFalse);
    expect(segment.containsKey('pitch_stddev_cents'), isFalse);
    expect(segment.containsKey('pitch_bias_cents'), isFalse);
    expect(segment.containsKey('interrupted'), isFalse);
    expect(segment.containsKey('recommendation'), isFalse);
  });
}
