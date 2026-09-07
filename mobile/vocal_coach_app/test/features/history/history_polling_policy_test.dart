import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/history/domain/history_polling_policy.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

AIJob _job(String state) {
  return AIJob(
    jobId: 'job-$state',
    sessionId: 'session-1',
    state: state,
    attempt: 0,
    maxAttempts: 1,
    queuedAt: 1,
    updatedAt: 1,
    mode: 'training',
    exerciseType: 'warmup_pitch',
  );
}

SessionDetailsResponse _session(
    {String status = 'completed', String? jobState}) {
  return SessionDetailsResponse(
    sessionId: 'session-1',
    userId: 'user-1',
    mode: 'training',
    exerciseType: 'warmup_pitch',
    status: status,
    aiJob: jobState == null ? null : _job(jobState),
  );
}

void main() {
  test('refreshes while a session or its AI job is active', () {
    expect(
        shouldRefreshPracticeHistory([_session(status: 'processing')]), isTrue);
    expect(
      shouldRefreshPracticeHistory([_session(jobState: 'pending_enqueue')]),
      isTrue,
    );
    expect(
        shouldRefreshPracticeHistory([_session(jobState: 'queued')]), isTrue);
    expect(
      shouldRefreshPracticeHistory([_session(jobState: 'processing')]),
      isTrue,
    );
  });

  test('does not refresh for terminal or idle sessions', () {
    expect(shouldRefreshPracticeHistory([_session()]), isFalse);
    expect(
      shouldRefreshPracticeHistory([_session(jobState: 'completed')]),
      isFalse,
    );
    expect(
      shouldRefreshPracticeHistory([_session(jobState: 'failed')]),
      isFalse,
    );
    expect(shouldRefreshPracticeHistory(const []), isFalse);
  });
}
