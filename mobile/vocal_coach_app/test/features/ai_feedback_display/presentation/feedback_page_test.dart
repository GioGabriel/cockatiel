import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/ai_feedback_display/presentation/feedback_page.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

void main() {
  testWidgets('explains the score and identifies the weakest measured area',
      (tester) async {
    final feedback = CoachingFeedback.fromJson({
      'session_id': 'session-1',
      'overall_score': 7,
      'strengths': ['You completed a practice attempt'],
      'improvements': ['Several notes drifted above or below the target'],
      'next_exercises': ['Slow note-matching drill'],
      'summary': 'Your pitch needs more consistent target-note matching.',
      'model_used': 'coaching-logic-engine',
      'prompt_version': 'v1',
      'latency_ms': 12,
      'detailed_improvements': [
        {
          'metric_key': 'pitch_accuracy',
          'priority': 'high',
          'finding': 'Several target notes were missed.',
          'evidence': 'Only 42% of target frames were on target.',
          'why_it_matters':
              'Matching the center of the note makes the melody clearer.',
          'action': 'Sing one target note at a time with the guide.',
          'practice_plan': 'Repeat the Mi section slowly three times.',
        },
      ],
      'score_breakdown': {
        'metric_mode': 'voice',
        'focus_metrics': [
          'pitch_accuracy',
          'timing_accuracy',
          'breath_control',
        ],
        'metric_scores': {
          'pitch_accuracy': 7.0,
          'timing_accuracy': 19.0,
          'breath_control': 24.0,
          'pitch_stability': 18.0,
          'vibrato_consistency': 12.0,
          'note_transition_smoothness': 15.0,
        },
        'weighted_components': {
          'pitch_accuracy': 2.1,
          'timing_accuracy': 3.8,
          'breath_control': 1.2,
        },
        'scoring_version': '2.0',
        'sample_count': 180,
        'evidence_quality': 'reliable',
        'recording_evidence': {
          'frame_count': 180,
          'voiced_coverage_pct': 96.0,
          'target_coverage_pct': 92.0,
        },
        'metric_details': {
          'pitch_accuracy': {
            'status': 'measured',
            'reason': 'Several target notes were missed.',
            'observed_frames': 166,
            'coverage_pct': 92.0,
          },
          'timing_accuracy': {
            'status': 'measured',
            'reason': 'Most target frames were present.',
            'observed_frames': 166,
            'coverage_pct': 92.0,
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
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(
          result: FinalizeResponse(
            sessionId: 'session-1',
            status: 'completed',
            feedback: feedback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('out of 100'), findsOneWidget);
    expect(find.text('How this score is calculated'), findsOneWidget);
    expect(find.text('Focus first'), findsOneWidget);
    expect(find.textContaining('Pitch accuracy'), findsWidgets);
    expect(find.textContaining('7/100'), findsWidgets);
    expect(find.textContaining('Reliable recording evidence'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Detailed coaching plan'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Detailed coaching plan'), findsOneWidget);
    expect(find.text('Several target notes were missed.'), findsOneWidget);
  });

  testWidgets('explains when zero pitch metrics are not measurable',
      (tester) async {
    final feedback = CoachingFeedback.fromJson({
      'session_id': 'session-2',
      'overall_score': 48,
      'strengths': ['Voice was captured'],
      'improvements': ['Start the target guide before singing'],
      'next_exercises': ['Microphone and target-note check'],
      'model_used': 'coaching-logic-engine-fallback',
      'score_breakdown': {
        'metric_mode': 'voice',
        'focus_metrics': ['pitch_accuracy', 'timing_accuracy'],
        'metric_scores': {
          'pitch_accuracy': 0.0,
          'timing_accuracy': 0.0,
          'breath_control': 48.0,
        },
        'weighted_components': {
          'pitch_accuracy': 0.0,
          'timing_accuracy': 0.0,
          'breath_control': 4.8,
        },
        'scoring_version': '2.1',
        'sample_count': 706,
        'evidence_quality': 'reliable',
        'score_status': 'not_scorable',
        'recording_evidence': {
          'frame_count': 706,
          'voiced_coverage_pct': 49.86,
          'target_coverage_pct': 0.0,
          'no_target_frame_count': 706,
        },
        'metric_details': {
          'pitch_accuracy': {
            'status': 'not_measurable',
            'reason':
                'No target-note comparison frames were captured because the target guide was not available in this take. The 0/100 is not a failed singing result; this part was not measurable.',
            'observed_frames': 0,
            'coverage_pct': 0.0,
          },
          'timing_accuracy': {
            'status': 'not_measurable',
            'reason': 'No target-note comparison frames were captured.',
            'observed_frames': 0,
            'coverage_pct': 0.0,
          },
          'breath_control': {
            'status': 'measured',
            'reason': 'Voice was present in about half of the captured frames.',
            'observed_frames': 352,
            'coverage_pct': 49.86,
          },
        },
        'segments': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(
          result: FinalizeResponse(
            sessionId: 'session-2',
            status: 'completed',
            feedback: feedback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Why some metrics show 0'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Why some metrics show 0'), findsOneWidget);
    expect(
        find.textContaining('No target-note comparison frames were captured'),
        findsWidgets);
    expect(find.textContaining('not a failed singing result'), findsWidgets);
  });

  testWidgets('does not present an unscorable take as a practice score',
      (tester) async {
    final feedback = CoachingFeedback.fromJson({
      'session_id': 'session-no-target',
      'overall_score': 0,
      'strengths': ['Voice was captured'],
      'improvements': ['Start the target guide before singing'],
      'next_exercises': ['Microphone and target-note check'],
      'model_used': 'coaching-logic-engine',
      'score_breakdown': {
        'metric_mode': 'voice',
        'focus_metrics': ['pitch_accuracy'],
        'metric_scores': {'pitch_accuracy': 0.0},
        'weighted_components': {'pitch_accuracy': 0.0},
        'scoring_version': '2.2',
        'sample_count': 64,
        'evidence_quality': 'reliable',
        'score_status': 'not_scorable',
        'recording_evidence': {
          'frame_count': 64,
          'target_frame_count': 0,
        },
        'metric_details': {
          'pitch_accuracy': {
            'status': 'not_measurable',
            'reason': 'No target-note comparison frames were captured.',
            'observed_frames': 0,
            'coverage_pct': 0.0,
          },
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(
          result: FinalizeResponse(
            sessionId: 'session-no-target',
            status: 'completed',
            feedback: feedback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not enough evidence to score this take reliably'),
        findsOneWidget);
    expect(find.text('Your practice score'), findsNothing);
  });

  testWidgets('explains breathing phase evidence', (tester) async {
    final feedback = CoachingFeedback.fromJson({
      'session_id': 'session-breathing',
      'overall_score': 72,
      'strengths': ['You completed most of the guided cycle'],
      'improvements': ['Finish each phase before moving on'],
      'next_exercises': ['Repeat the breathing ladder'],
      'model_used': 'coaching-logic-engine',
      'score_breakdown': {
        'metric_mode': 'breathing',
        'focus_metrics': ['phase_completion_rate', 'pace_adherence'],
        'metric_scores': {
          'phase_completion_rate': 75.0,
          'pace_adherence': 64.0,
        },
        'weighted_components': {
          'phase_completion_rate': 26.25,
          'pace_adherence': 19.2,
        },
        'scoring_version': '2.1',
        'sample_count': 30,
        'evidence_quality': 'limited',
        'recording_evidence': {
          'phase_count': 4,
          'completed_phase_count': 3,
          'phase_coverage_pct': 75.0,
          'interruption_count': 1,
        },
        'metric_details': {
          'phase_completion_rate': {
            'status': 'partial',
            'reason': '3 of 4 guided breathing phases were completed.',
            'observed_frames': 3,
            'coverage_pct': 75.0,
          },
          'pace_adherence': {
            'status': 'partial',
            'reason':
                'The guided routine recorded 3 of 4 completed phases and 1 interruption.',
            'observed_frames': 3,
            'coverage_pct': 75.0,
          },
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(
          result: FinalizeResponse(
            sessionId: 'session-breathing',
            status: 'completed',
            feedback: feedback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('3 of 4 guided phases'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3 of 4 guided phases'), findsWidgets);
    expect(find.textContaining('1 interruption recorded'), findsWidgets);
  });
}
