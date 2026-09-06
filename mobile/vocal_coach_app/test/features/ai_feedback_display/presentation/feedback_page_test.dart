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
  });
}
