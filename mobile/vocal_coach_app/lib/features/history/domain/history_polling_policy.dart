import '../../../../shared/models/session_models.dart';

/// Returns whether the history list can change without user interaction.
///
/// A session may remain `completed` while its nested AI job is still waiting
/// to be enqueued or processed, so both layers must be considered. This is a
/// polling decision only; it does not infer that a job succeeded.
bool shouldRefreshPracticeHistory(
  Iterable<SessionDetailsResponse> sessions,
) {
  return sessions.any((session) {
    if (session.status == 'processing' || session.status == 'queued') {
      return true;
    }

    final jobState = session.aiJob?.state;
    return jobState == 'pending_enqueue' ||
        jobState == 'queued' ||
        jobState == 'processing';
  });
}
