import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../shared/models/session_models.dart';
import '../../../shared/utils/vocal_utils.dart';
import '../../../shared/widgets/animated_score_display.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/voice_studio.dart';

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
  'breath_control':
      'A continuity and loudness proxy from the microphone, not direct airflow.',
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

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your practice review')),
      body: VoiceStageBackground(
          child: feedback == null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.hourglass_top_rounded, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                            'Your review is being prepared. You can find it in Practice history.'),
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back')),
                      ])))
              : ListView(padding: const EdgeInsets.all(20), children: [
                  StudioCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        if (_isUnscorable(scoreBreakdown))
                          Text(
                              'Not enough evidence to score this take reliably',
                              style: theme.textTheme.titleLarge)
                        else ...[
                          const Text('Your practice score',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Center(
                              child: SizedBox.square(
                                  dimension: 156,
                                  child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox.expand(
                                            child: CircularProgressIndicator(
                                                value: (feedback.overallScore /
                                                        100)
                                                    .clamp(0, 1),
                                                strokeWidth: 10,
                                                backgroundColor: theme
                                                    .colorScheme.outlineVariant,
                                                strokeCap: StrokeCap.round)),
                                        Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedScoreDisplay(
                                                  score: feedback.overallScore
                                                      .round(),
                                                  style: theme
                                                      .textTheme.displayMedium),
                                              const Text('out of 100'),
                                            ]),
                                      ]))),
                        ],
                        if (feedback.summary?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 20),
                          Text(feedback.summary!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ],
                        if (scoreBreakdown != null &&
                            !_isUnscorable(scoreBreakdown)) ...[
                          const SizedBox(height: 20),
                          ...scoreBreakdown.metricScores.entries
                              .where((entry) =>
                                  scoreBreakdown
                                      .metricDetails[entry.key]?.status !=
                                  'not_measurable')
                              .take(3)
                              .map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(
                                              _metricLabels[entry.key] ??
                                                  entry.key)),
                                      Text('${entry.value.round()}%')
                                    ]),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                        value: (entry.value / 100).clamp(0, 1),
                                        minHeight: 7,
                                        borderRadius: BorderRadius.circular(8)),
                                  ]))),
                        ],
                      ])),
                  if (feedback.improvements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    StudioCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Your next small step',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(feedback.improvements.first,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                        ])),
                  ],
                  const SizedBox(height: 16),
                  Card(
                      child: ExpansionTile(
                          title: const Text('Read full feedback'),
                          subtitle: const Text(
                              'Scores, coaching notes and what to practice next'),
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                        if (feedback.summary != null) Text(feedback.summary!),
                        if (scoreBreakdown != null)
                          _ScoreBreakdownCard(breakdown: scoreBreakdown),
                        if (feedback.detailedImprovements.isNotEmpty)
                          _DetailedImprovementsCard(
                              key: const Key('detailed-coaching-plan'),
                              improvements: feedback.detailedImprovements,
                              aiGenerated: feedback.modelUsed
                                  .startsWith('google-ai-studio:')),
                        const _TerminologyCard(),
                        _FeedbackSection(
                            title: 'Strengths', items: feedback.strengths),
                        _FeedbackSection(
                            title: 'Improvements',
                            items: feedback.improvements),
                        _FeedbackSection(
                            title: 'Next Exercises',
                            items: feedback.nextExercises),
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_friendlySource(feedback.modelUsed),
                                style: theme.textTheme.bodySmall)),
                      ])),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                      child: const Text('Back to Home')),
                ])),
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
              _isUnscorable(breakdown)
                  ? 'The numeric components below are retained for diagnostics, but this take is not a fair overall score.'
                  : 'Your ${breakdown.metricMode == 'breathing' ? 'breathing' : 'voice'} score is a weighted combination of these measured areas.',
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
                          '${evidence.description} ${breakdown.metricMode == 'breathing' ? 'Based on ${breakdown.sampleCount} seconds of guided timing.' : 'Based on ${breakdown.sampleCount} analyzed audio samples.'}',
                          style:
                              theme.textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (breakdown.recordingEvidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              _RecordingEvidenceSummary(evidence: breakdown.recordingEvidence),
            ],
            if (weakestKey != null &&
                !_isUnscorable(breakdown) &&
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
            if (weakestKey == null && breakdown.metricDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MeasurementGapNotice(breakdown: breakdown),
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
                    detail: breakdown.metricDetails[entry.value],
                    isFirst: entry.key == 0,
                  ),
                ),
            const SizedBox(height: 12),
            if (breakdown.segments.isNotEmpty) ...[
              _SegmentsEvidenceCard(segments: breakdown.segments),
              const SizedBox(height: 8),
            ],
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
    final measurableCandidates = candidates.where((key) {
      final status = breakdown.metricDetails[key]?.status;
      return status != 'not_measurable' && status != 'not_applicable';
    }).toList(growable: false);
    if (measurableCandidates.isEmpty) return null;

    return measurableCandidates.reduce(
      (current, next) =>
          breakdown.metricScores[current]! <= breakdown.metricScores[next]!
              ? current
              : next,
    );
  }
}

bool _isUnscorable(FeedbackScoreBreakdown? breakdown) {
  final status = breakdown?.scoreStatus;
  return status == 'not_scorable' || status == 'insufficient_evidence';
}

class _MetricScoreRow extends StatelessWidget {
  const _MetricScoreRow({
    required this.metricKey,
    required this.score,
    required this.weightedContribution,
    this.detail,
    required this.isFirst,
  });

  final String metricKey;
  final double score;
  final double? weightedContribution;
  final FeedbackMetricDetail? detail;
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
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!.reason,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: detail!.status == 'not_measurable'
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
                _scoreBand(safeScore, detail?.status),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: detail?.status == 'not_measurable'
                      ? theme.colorScheme.onSurfaceVariant
                      : color,
                ),
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

class _MeasurementGapNotice extends StatelessWidget {
  const _MeasurementGapNotice({required this.breakdown});

  final FeedbackScoreBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final details = breakdown.metricDetails.values
        .where((detail) => detail.status == 'not_measurable')
        .toList(growable: false);
    if (details.isEmpty && !_isUnscorable(breakdown)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why some metrics show 0',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            details.isEmpty
                ? 'The recording did not contain enough usable target evidence for a fair score. This is an evidence gap, not a judgment about your singing.'
                : details.first.reason,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RecordingEvidenceSummary extends StatelessWidget {
  const _RecordingEvidenceSummary({required this.evidence});

  final Map<String, dynamic> evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (evidence.containsKey('phase_count')) {
      final phaseCount = _number(evidence['phase_count']).round();
      final completedPhaseCount =
          _number(evidence['completed_phase_count']).round();
      final interruptions = _number(evidence['interruption_count']).round();
      final interruptionLabel =
          interruptions == 1 ? 'interruption' : 'interruptions';
      return Text(
        '$completedPhaseCount of $phaseCount guided phases completed • '
        '$interruptions $interruptionLabel recorded',
        style: theme.textTheme.labelSmall?.copyWith(height: 1.35),
      );
    }
    final frameCount = _number(evidence['frame_count']).round();
    final voicedCoverage = _number(evidence['voiced_coverage_pct']);
    final targetCoverage = _number(evidence['target_coverage_pct']);
    final interruptions = _number(evidence['interruption_count']).round();
    final interruptionLabel =
        interruptions == 1 ? 'interruption' : 'interruptions';
    final gaps = _number(evidence['stream_gap_count']).round();
    return Text(
      '$frameCount captured frames • ${voicedCoverage.toStringAsFixed(0)}% voiced coverage • '
      '${targetCoverage.toStringAsFixed(0)}% target comparison • '
      '$interruptions $interruptionLabel${gaps == 0 ? '' : ' • $gaps stream gaps'}',
      style: theme.textTheme.labelSmall?.copyWith(height: 1.35),
    );
  }
}

class _SegmentsEvidenceCard extends StatelessWidget {
  const _SegmentsEvidenceCard({required this.segments});

  final List<FeedbackSegmentEvidence> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where this happened', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        ...segments.take(8).map(
              (segment) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      segment.status == 'not_measurable'
                          ? Icons.help_outline_rounded
                          : Icons.music_note_rounded,
                      size: 18,
                      color: segment.status == 'not_measurable'
                          ? theme.colorScheme.onSurfaceVariant
                          : _scoreColor(theme, segment.score),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${segment.label ?? segment.segmentId} (${(segment.startMs / 1000).toStringAsFixed(1)}–${(segment.endMs / 1000).toStringAsFixed(1)}s): ${_scoreText(segment.score)}${segment.targetFrequencyHz == null ? '' : ' · target ${segment.targetFrequencyHz!.toStringAsFixed(1)} Hz'} — ${segment.reason}${segment.recommendation == null ? '' : ' ${segment.recommendation}'}',
                        style:
                            theme.textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DetailedImprovementsCard extends StatelessWidget {
  const _DetailedImprovementsCard({
    super.key,
    required this.improvements,
    required this.aiGenerated,
  });

  final List<DetailedImprovement> improvements;
  final bool aiGenerated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard.dark(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detailed coaching plan', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              aiGenerated
                  ? 'Gemini turned the measured evidence into these specific next actions.'
                  : 'These actions were generated from the measured score evidence.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 12),
            ...improvements.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == improvements.length - 1 ? 0 : 12,
                    ),
                    child: _ImprovementPlan(
                      index: entry.key + 1,
                      improvement: entry.value,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ImprovementPlan extends StatelessWidget {
  const _ImprovementPlan({required this.index, required this.improvement});

  final int index;
  final DetailedImprovement improvement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = improvement.priority == 'high'
        ? theme.colorScheme.error
        : improvement.priority == 'low'
            ? theme.appTokens.success
            : theme.appTokens.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: priorityColor.withValues(alpha: 0.16),
                child: Text(
                  '$index',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _metricLabel(improvement.metricKey),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                improvement.priority.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: priorityColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(improvement.finding, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          if (improvement.startMs != null && improvement.endMs != null)
            _PlanLine(
              label: 'Where',
              value:
                  '${improvement.segmentId ?? 'Target'} • ${(improvement.startMs! / 1000).toStringAsFixed(1)}–${(improvement.endMs! / 1000).toStringAsFixed(1)}s',
            ),
          _PlanLine(label: 'Evidence', value: improvement.evidence),
          _PlanLine(label: 'Why it matters', value: improvement.whyItMatters),
          _PlanLine(label: 'Do this next', value: improvement.action),
          _PlanLine(label: 'Practice plan', value: improvement.practicePlan),
          if (improvement.limitation != null)
            _PlanLine(label: 'Limit', value: improvement.limitation!),
        ],
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
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

double _number(Object? value) {
  return value is num ? value.toDouble() : 0;
}

String _scoreText(double score) => '${score.round()}/100';

String _scoreBand(double score, [String? status]) {
  if (status == 'not_measurable') return 'Not measurable';
  if (status == 'not_applicable') return 'Not tested';
  if (status == 'partial') return 'Partial evidence';
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
      return 'Take a relaxed breath before the phrase and aim for a comfortably continuous voice signal until it ends.';
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
