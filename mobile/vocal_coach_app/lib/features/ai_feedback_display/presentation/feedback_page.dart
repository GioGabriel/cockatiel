import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/animated_score_display.dart';
import '../../../shared/widgets/glass_card.dart';

const _voiceMetricOrder = [
  'pitch_accuracy',
  'timing_accuracy',
  'breath_control',
  'pitch_stability',
  'vibrato_consistency',
  'note_transition_smoothness',
];

const _breathingMetricOrder = [
  'phase_completion_rate',
  'pace_adherence',
  'cycle_consistency',
  'completion_rate',
];

const _metricLabels = {
  'pitch_accuracy': 'Pitch accuracy',
  'timing_accuracy': 'Timing',
  'breath_control': 'Breath control',
  'pitch_stability': 'Note steadiness',
  'vibrato_consistency': 'Vibrato control',
  'note_transition_smoothness': 'Note transitions',
  'phase_completion_rate': 'Breathing phases',
  'pace_adherence': 'Breathing pace',
  'cycle_consistency': 'Cycle consistency',
  'completion_rate': 'Routine completion',
};

const _metricDescriptions = {
  'pitch_accuracy': 'How closely you matched each target note.',
  'timing_accuracy': 'How closely your notes followed the expected timing.',
  'breath_control': 'How steadily your airflow lasted through each phrase.',
  'pitch_stability': 'How steady each held note remained after you reached it.',
  'vibrato_consistency':
      'How even and controlled your natural pitch movement was.',
  'note_transition_smoothness':
      'How smoothly you moved from one target note to the next.',
  'phase_completion_rate':
      'How consistently you completed each breathing phase.',
  'pace_adherence': 'How closely your breathing followed the guided pace.',
  'cycle_consistency': 'How evenly your breathing cycles repeated.',
  'completion_rate': 'How much of the guided breathing routine you completed.',
};

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key, required this.result});

  final FinalizeResponse result;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;
    final scoreBreakdown = feedback?.scoreBreakdown;

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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AnimatedScoreDisplay(
                                score: feedback.overallScore.round(),
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              Text(
                                'out of 100',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feedback.scoreBreakdown == null
                                ? 'Your score is measured out of 100.'
                                : 'This score combines the measurable parts of this take. Lower areas below show where to focus first.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.4),
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
                  if (scoreBreakdown != null) ...[
                    _ScoreBreakdownCard(breakdown: scoreBreakdown),
                    const SizedBox(height: 8),
                  ],
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
    if (modelUsed.startsWith('google-ai-studio:')) {
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
              'Each row above is one part of this recording, scored from 0 to 100. '
              'The lowest measured area is the first place to practice. These are practice clues, not a diagnosis.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBreakdownCard extends StatelessWidget {
  const _ScoreBreakdownCard({required this.breakdown});

  final FeedbackScoreBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metricKeys = _orderedMetricKeys();
    final weakestKey = _weakestMetric(metricKeys);
    final evidence = _evidenceDetails(breakdown.evidenceQuality);

    return GlassCard.dark(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this score is calculated',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Your ${breakdown.metricMode == 'breathing' ? 'breathing' : 'voice'} score is a weighted combination of these measured areas.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: evidence.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: evidence.color.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.graphic_eq, color: evidence.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evidence.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: evidence.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${evidence.description} Based on ${breakdown.sampleCount} analyzed audio samples.',
                          style:
                              theme.textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (weakestKey != null &&
                breakdown.evidenceQuality != 'insufficient') ...[
              const SizedBox(height: 12),
              Text(
                'Focus first',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${_metricLabel(weakestKey)} was the lowest measured area in this take (${_scoreText(breakdown.metricScores[weakestKey]!)}).',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 4),
              Text(
                _practiceSuggestion(weakestKey),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ],
            if (metricKeys.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'A detailed metric breakdown was not available for this session.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            ...metricKeys.asMap().entries.map(
                  (entry) => _MetricScoreRow(
                    metricKey: entry.value,
                    score: breakdown.metricScores[entry.value]!,
                    weightedContribution:
                        breakdown.weightedComponents[entry.value],
                    isFirst: entry.key == 0,
                  ),
                ),
            const SizedBox(height: 12),
            Text(
              'Scoring version ${breakdown.scoringVersion}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _orderedMetricKeys() {
    final preferredOrder = breakdown.metricMode == 'breathing'
        ? _breathingMetricOrder
        : _voiceMetricOrder;
    return preferredOrder
        .where(breakdown.metricScores.containsKey)
        .toList(growable: false);
  }

  String? _weakestMetric(List<String> metricKeys) {
    final focusKeys = breakdown.focusMetrics
        .where(breakdown.metricScores.containsKey)
        .toList(growable: false);
    final candidates = focusKeys.isEmpty ? metricKeys : focusKeys;
    if (candidates.isEmpty) return null;

    return candidates.reduce(
      (current, next) =>
          breakdown.metricScores[current]! <= breakdown.metricScores[next]!
              ? current
              : next,
    );
  }
}

class _MetricScoreRow extends StatelessWidget {
  const _MetricScoreRow({
    required this.metricKey,
    required this.score,
    required this.weightedContribution,
    required this.isFirst,
  });

  final String metricKey;
  final double score;
  final double? weightedContribution;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeScore = score.clamp(0, 100).toDouble();
    final color = _scoreColor(theme, safeScore);

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _metricLabel(metricKey),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                _scoreText(safeScore),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _metricDescriptions[metricKey] ?? 'Measured part of this take.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: safeScore / 100,
              minHeight: 8,
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _scoreBand(safeScore),
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
              if (weightedContribution != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• contributes ${weightedContribution!.toStringAsFixed(1)} points',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceDetails {
  const _EvidenceDetails({
    required this.title,
    required this.description,
    required this.color,
  });

  final String title;
  final String description;
  final Color color;
}

_EvidenceDetails _evidenceDetails(String quality) {
  switch (quality) {
    case 'reliable':
      return const _EvidenceDetails(
        title: 'Reliable recording evidence',
        description: 'There was enough audio data for a useful practice score.',
        color: Colors.green,
      );
    case 'limited':
      return const _EvidenceDetails(
        title: 'Limited recording evidence',
        description:
            'The score is useful as a guide, but a longer take will be more dependable.',
        color: Colors.orange,
      );
    case 'insufficient':
      return const _EvidenceDetails(
        title: 'Not enough recording evidence',
        description:
            'Use the microphone check and record a little more before judging this score.',
        color: Colors.red,
      );
    default:
      return const _EvidenceDetails(
        title: 'Recording evidence',
        description:
            'This score is based on the audio captured during the session.',
        color: Colors.blue,
      );
  }
}

String _metricLabel(String metricKey) {
  return _metricLabels[metricKey] ?? formatSnakeCaseTitle(metricKey);
}

String _scoreText(double score) => '${score.round()}/100';

String _scoreBand(double score) {
  if (score >= 85) return 'Strong';
  if (score >= 70) return 'Developing';
  return 'Focus here';
}

Color _scoreColor(ThemeData theme, double score) {
  if (score >= 85) return theme.appTokens.success;
  if (score >= 70) return theme.appTokens.warning;
  return theme.colorScheme.error;
}

String _practiceSuggestion(String metricKey) {
  switch (metricKey) {
    case 'pitch_accuracy':
      return 'Practice one target note at a time with a steady reference tone, then repeat the phrase slowly.';
    case 'timing_accuracy':
      return 'Count the beat before each phrase and repeat the same section with a quiet metronome.';
    case 'breath_control':
      return 'Take a relaxed breath before the phrase and aim to keep the airflow steady until it ends.';
    case 'pitch_stability':
      return 'Hold short notes comfortably, keeping the sound even instead of pushing for volume.';
    case 'vibrato_consistency':
      return 'Keep vibrato natural and gentle; first make the sustained note steady, then add movement.';
    case 'note_transition_smoothness':
      return 'Slow down the two-note changes and connect each target without sliding past it.';
    case 'phase_completion_rate':
      return 'Follow each inhale, hold, and exhale to the final count before starting the next cycle.';
    case 'pace_adherence':
      return 'Let the guide set the speed and keep each inhale or exhale relaxed rather than rushed.';
    case 'cycle_consistency':
      return 'Repeat the same breathing pattern at a comfortable pace so each cycle feels similar.';
    case 'completion_rate':
      return 'Use a shorter routine first, then complete the full sequence one calm phase at a time.';
    default:
      return 'Repeat this exercise slowly and focus on the lowest measured area.';
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
