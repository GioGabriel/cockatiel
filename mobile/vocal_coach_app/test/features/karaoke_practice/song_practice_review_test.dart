import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/karaoke_practice/domain/song_practice_review.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

void main() {
  test('a rejected take stays unsaved so the singer can record a new take',
      () async {
    final controller = SongPracticeReviewController();
    var saves = 0;
    Future<void> save() async {
      saves++;
      if (saves == 1) throw StateError('insufficient audio evidence');
    }

    Future<FinalizeResponse> review() async =>
        FinalizeResponse(sessionId: 'song', status: 'completed');
    await expectLater(controller.submit(saveAttempt: save, finalize: review),
        throwsStateError);
    expect(controller.hasSavedAttempt, isFalse);
    await controller.submit(saveAttempt: save, finalize: review);
    expect(controller.hasSavedAttempt, isTrue);
    expect(saves, 2);
  });
  test('a failed review can retry without saving the same take twice',
      () async {
    final controller = SongPracticeReviewController();
    var saves = 0;
    var reviews = 0;
    final expected = FinalizeResponse(sessionId: 'song', status: 'completed');
    Future<void> save() async {
      saves++;
    }

    Future<FinalizeResponse> review() async {
      reviews++;
      if (reviews == 1) throw StateError('temporary outage');
      return expected;
    }

    await expectLater(controller.submit(saveAttempt: save, finalize: review),
        throwsStateError);
    expect(await controller.submit(saveAttempt: save, finalize: review),
        same(expected));
    expect(saves, 1);
    expect(reviews, 2);
  });

  test('concurrent finish actions share one save and preserve the feedback',
      () async {
    final controller = SongPracticeReviewController();
    var saves = 0;
    final feedback = CoachingFeedback(
        sessionId: 'song',
        overallScore: 72,
        strengths: ['Steady notes'],
        improvements: ['Practice timing'],
        nextExercises: ['Slow phrases'],
        modelUsed: 'coaching-logic-engine');
    Future<void> save() async {
      saves++;
    }

    Future<FinalizeResponse> review() async => FinalizeResponse(
        sessionId: 'song', status: 'completed', feedback: feedback);
    final results = await Future.wait([
      controller.submit(saveAttempt: save, finalize: review),
      controller.submit(saveAttempt: save, finalize: review),
    ]);
    expect(saves, 1);
    expect(results.every((result) => identical(result.feedback, feedback)),
        isTrue);
  });
}
