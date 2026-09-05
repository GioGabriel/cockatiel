import 'package:flutter/material.dart';

import '../../../shared/models/session_models.dart';
import '../../../shared/widgets/animated_score_display.dart';
import '../../../shared/widgets/glass_card.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key, required this.result});

  final FinalizeResponse result;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: feedback == null
            ? Center(
                child: Text(
                  'Session ${result.sessionId} is ${result.status}. Feedback is not ready yet.',
                ),
              )
            : ListView(
                children: [
                  GlassCard.dark(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your practice score',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          AnimatedScoreDisplay(
                            score: feedback.overallScore.round(),
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          if (feedback.summary != null &&
                              feedback.summary!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Your takeaway',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feedback.summary!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _TerminologyCard(),
                  const SizedBox(height: 8),
                  _FeedbackSection(
                      title: 'Strengths', items: feedback.strengths),
                  const SizedBox(height: 8),
                  _FeedbackSection(
                      title: 'Improvements', items: feedback.improvements),
                  const SizedBox(height: 8),
                  _FeedbackSection(
                      title: 'Next Exercises', items: feedback.nextExercises),
                  const SizedBox(height: 16),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Details for advanced users'),
                      subtitle: Text(_friendlySource(feedback.modelUsed)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Feedback source: ${_friendlySource(feedback.modelUsed)}\n'
                            'Prompt version: ${feedback.promptVersion ?? 'Not provided'}\n'
                            'Review time: ${feedback.latencyMs != null ? '${feedback.latencyMs} ms' : 'Not provided'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
      ),
    );
  }

  static String _friendlySource(String modelUsed) {
    if (modelUsed.startsWith('coaching-logic-engine')) {
      return 'Local coaching logic (available without remote AI)';
    }
    if (modelUsed.startsWith('openrouter:')) {
      return 'Optional AI summary with local coaching metrics';
    }
    return 'Coaching review';
  }
}

class _TerminologyCard extends StatelessWidget {
  const _TerminologyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What the feedback means', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Pitch accuracy means matching the target note. Timing means singing at the right moment. '
              'Breath support means keeping airflow steady. These are practice clues, not a diagnosis.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard.dark(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
