import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/state/app_state.dart';
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

void main() {
  test('AI polling is disabled when there are no jobs', () {
    expect(shouldPollAIJobs(const <AIJob>[]), isFalse);
  });

  test('AI polling continues only while a job is active', () {
    expect(shouldPollAIJobs([_job('pending_enqueue')]), isTrue);
    expect(shouldPollAIJobs([_job('queued')]), isTrue);
    expect(shouldPollAIJobs([_job('processing')]), isTrue);
    expect(shouldPollAIJobs([_job('completed')]), isFalse);
    expect(shouldPollAIJobs([_job('failed')]), isFalse);
  });
}
