import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/ai_feedback_display/presentation/session_feedback_wait_page.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

void main() {
  testWidgets(
      'a stalled review request times out and releases the retry action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SessionFeedbackWaitPage(
      onOpenQueue: () {},
      requestTimeout: Duration.zero,
      loadReview: () => Completer<FinalizeResponse>().future,
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('a saved song automatically opens its feedback when ready',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: SessionFeedbackWaitPage(
      onOpenQueue: () {},
      loadReview: () async {
        calls++;
        return FinalizeResponse(
            sessionId: 'song',
            status: calls == 1 ? 'processing' : 'completed',
            feedback: calls == 1
                ? null
                : CoachingFeedback(
                    sessionId: 'song',
                    overallScore: 75,
                    strengths: [],
                    improvements: [],
                    nextExercises: [],
                    modelUsed: 'coaching-logic-engine'));
      },
    )));
    await tester.pump();
    expect(find.text('Your take is saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Your practice review'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
  });

  testWidgets('unavailable feedback offers retry and the saved review queue',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SessionFeedbackWaitPage(
      onOpenQueue: () {},
      loadReview: () async => throw StateError('offline'),
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Open saved reviews'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
