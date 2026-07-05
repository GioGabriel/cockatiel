import 'package:flutter/material.dart';

import '../../../shared/models/session_models.dart';
import '../../../shared/widgets/animated_score_display.dart';

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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Score',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          AnimatedScoreDisplay(
                            score: feedback.overallScore.round(),
                            style:
                                Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Model: ${feedback.modelUsed} | Prompt: ${feedback.promptVersion ?? '-'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FeedbackSection(
                      title: 'Strengths', items: feedback.strengths),
                  const SizedBox(height: 10),
                  _FeedbackSection(
                      title: 'Improvements', items: feedback.improvements),
                  const SizedBox(height: 10),
                  _FeedbackSection(
                      title: 'Next Exercises', items: feedback.nextExercises),
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
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
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
