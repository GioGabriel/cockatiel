import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/session_models.dart';
import 'feedback_page.dart';

class AnalysisQueuePage extends StatelessWidget {
  const AnalysisQueuePage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analysis Queue'),
        actions: [
          IconButton(
            onPressed: appState.refreshAIJobs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (_, __) {
          final jobs = appState.aiJobs;
          if (jobs.isEmpty) {
            return const Center(
              child:
                  Text('No analysis jobs yet. Start a session to queue one.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (_, index) {
              final job = jobs[index];
              return _QueueJobCard(
                job: job,
                apiClient: apiClient,
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueJobCard extends StatelessWidget {
  const _QueueJobCard({required this.job, required this.apiClient});

  final AIJob job;
  final ApiClient apiClient;

  String _statusLabel() {
    switch (job.state) {
      case 'queued':
        return 'Queued';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return job.state;
    }
  }

  Future<void> _openFeedback(BuildContext context) async {
    final session = await apiClient.fetchSession(sessionId: job.sessionId);
    CoachingFeedback? feedback = session.feedback;
    if (feedback == null && session.status == 'completed') {
      feedback = await apiClient.fetchFeedback(sessionId: job.sessionId);
    }
    if (!context.mounted || feedback == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedbackPage(
          result: FinalizeResponse(
            sessionId: job.sessionId,
            status: 'completed',
            feedback: feedback,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (job.state) {
      'completed' => Colors.green,
      'failed' => theme.colorScheme.error,
      'processing' => theme.colorScheme.primary,
      _ => theme.colorScheme.secondary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.exerciseType,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Session: ${job.sessionId}'),
            Text('Attempts: ${job.attempt + 1}/${job.maxAttempts}'),
            if (job.lastError != null && job.lastError!.isNotEmpty)
              Text(
                'Last error: ${job.lastError}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 8),
            if (job.state == 'completed')
              FilledButton.tonal(
                onPressed: () => _openFeedback(context),
                child: const Text('Open Feedback'),
              ),
          ],
        ),
      ),
    );
  }
}
