import 'training_models.dart';

class SessionCreateResponse {
  SessionCreateResponse({required this.sessionId, required this.status});

  final String sessionId;
  final String status;

  factory SessionCreateResponse.fromJson(Map<String, dynamic> json) {
    return SessionCreateResponse(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
    );
  }
}

class CanonicalMetricFrame {
  CanonicalMetricFrame({
    required this.sessionId,
    required this.timestampMs,
    required this.exerciseType,
    required this.pitchAccuracy,
    required this.timingAccuracy,
    required this.breathControl,
    required this.pitchStability,
    required this.vibratoConsistency,
    required this.noteTransitionSmoothness,
  });

  final String sessionId;
  final int timestampMs;
  final String exerciseType;
  final double pitchAccuracy;
  final double timingAccuracy;
  final double breathControl;
  final double pitchStability;
  final double vibratoConsistency;
  final double noteTransitionSmoothness;

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'timestamp_ms': timestampMs,
      'exercise_type': exerciseType,
      'pitch_accuracy': pitchAccuracy,
      'timing_accuracy': timingAccuracy,
      'breath_control': breathControl,
      'pitch_stability': pitchStability,
      'vibrato_consistency': vibratoConsistency,
      'note_transition_smoothness': noteTransitionSmoothness,
    };
  }
}

class MetricsAcceptedResponse {
  MetricsAcceptedResponse({
    required this.sessionId,
    required this.acceptedCount,
    required this.status,
  });

  final String sessionId;
  final int acceptedCount;
  final String status;

  factory MetricsAcceptedResponse.fromJson(Map<String, dynamic> json) {
    return MetricsAcceptedResponse(
      sessionId: json['session_id'] as String,
      acceptedCount: json['accepted_count'] as int,
      status: json['status'] as String,
    );
  }
}

class FeedbackScoreBreakdown {
  FeedbackScoreBreakdown({
    required this.metricMode,
    required this.focusMetrics,
    required this.metricScores,
    required this.weightedComponents,
    required this.scoringVersion,
    required this.sampleCount,
    required this.evidenceQuality,
    this.recordingEvidence = const <String, dynamic>{},
    this.metricDetails = const <String, FeedbackMetricDetail>{},
    this.segments = const <FeedbackSegmentEvidence>[],
  });

  final String metricMode;
  final List<String> focusMetrics;
  final Map<String, double> metricScores;
  final Map<String, double> weightedComponents;
  final String scoringVersion;
  final int sampleCount;
  final String evidenceQuality;
  final Map<String, dynamic> recordingEvidence;
  final Map<String, FeedbackMetricDetail> metricDetails;
  final List<FeedbackSegmentEvidence> segments;

  factory FeedbackScoreBreakdown.fromJson(Map<String, dynamic> json) {
    final rawMetricScores =
        json['metric_scores'] as Map<String, dynamic>? ?? const {};
    final rawWeightedComponents =
        json['weighted_components'] as Map<String, dynamic>? ?? const {};
    final rawMetricDetails =
        _mapFromJson(json['metric_details']) ?? const <String, dynamic>{};
    final rawSegments = json['segments'] as List<dynamic>? ?? const <dynamic>[];

    return FeedbackScoreBreakdown(
      metricMode: (json['metric_mode'] as String?) ?? 'voice',
      focusMetrics:
          (json['focus_metrics'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      metricScores: rawMetricScores.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      weightedComponents: rawWeightedComponents.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      scoringVersion: (json['scoring_version'] as String?) ?? 'unknown',
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      evidenceQuality: (json['evidence_quality'] as String?) ?? 'unknown',
      recordingEvidence:
          _mapFromJson(json['recording_evidence']) ?? const <String, dynamic>{},
      metricDetails: rawMetricDetails.map(
        (key, value) => MapEntry(
          key,
          FeedbackMetricDetail.fromJson(
            value is Map ? Map<String, dynamic>.from(value) : const {},
          ),
        ),
      ),
      segments: rawSegments
          .whereType<Map>()
          .map(
            (item) => FeedbackSegmentEvidence.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }

  static FeedbackScoreBreakdown? fromTrainingAttempt(TrainingAttempt attempt) {
    final attemptBreakdown = attempt.scoreBreakdown;
    if (attemptBreakdown == null) return null;

    final sampleCount = attemptBreakdown.sampleCount > 0
        ? attemptBreakdown.sampleCount
        : attempt.metricSummary.sampleCount;
    final evidenceQuality = attemptBreakdown.evidenceQuality == 'unknown'
        ? _evidenceQualityForSampleCount(sampleCount)
        : attemptBreakdown.evidenceQuality;

    return FeedbackScoreBreakdown(
      metricMode: attempt.metricSummary.metricMode,
      focusMetrics: attemptBreakdown.focusMetrics,
      metricScores: attemptBreakdown.metricScores,
      weightedComponents: attemptBreakdown.weightedComponents,
      scoringVersion: attemptBreakdown.scoringVersion,
      sampleCount: sampleCount,
      evidenceQuality: evidenceQuality,
      recordingEvidence: attemptBreakdown.recordingEvidence,
      metricDetails: attemptBreakdown.metricDetails,
      segments: attemptBreakdown.segments,
    );
  }

  static String _evidenceQualityForSampleCount(int sampleCount) {
    if (sampleCount < 16) return 'insufficient';
    if (sampleCount < 128) return 'limited';
    return 'reliable';
  }
}

class FeedbackMetricDetail {
  const FeedbackMetricDetail({
    required this.status,
    required this.reason,
    required this.observedFrames,
    required this.coveragePct,
    this.action,
  });

  final String status;
  final String reason;
  final int observedFrames;
  final double coveragePct;
  final String? action;

  factory FeedbackMetricDetail.fromJson(Map<String, dynamic> json) {
    return FeedbackMetricDetail(
      status: (json['status'] as String?) ?? 'measured',
      reason: (json['reason'] as String?) ??
          'Measured from the captured audio evidence.',
      observedFrames: (json['observed_frames'] as num?)?.toInt() ?? 0,
      coveragePct: (json['coverage_pct'] as num?)?.toDouble() ?? 0,
      action: json['action'] as String?,
    );
  }
}

class FeedbackSegmentEvidence {
  const FeedbackSegmentEvidence({
    required this.segmentId,
    required this.label,
    required this.startMs,
    required this.endMs,
    required this.score,
    required this.status,
    required this.reason,
  });

  final String segmentId;
  final String? label;
  final int startMs;
  final int endMs;
  final double score;
  final String status;
  final String reason;

  factory FeedbackSegmentEvidence.fromJson(Map<String, dynamic> json) {
    return FeedbackSegmentEvidence(
      segmentId: (json['segment_id'] as String?) ?? 'segment',
      label: json['label'] as String?,
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?) ?? 'measured',
      reason:
          (json['reason'] as String?) ?? 'Measured from this target window.',
    );
  }
}

class DetailedImprovement {
  const DetailedImprovement({
    required this.metricKey,
    required this.priority,
    required this.finding,
    required this.evidence,
    required this.whyItMatters,
    required this.action,
    required this.practicePlan,
  });

  final String metricKey;
  final String priority;
  final String finding;
  final String evidence;
  final String whyItMatters;
  final String action;
  final String practicePlan;

  factory DetailedImprovement.fromJson(Map<String, dynamic> json) {
    return DetailedImprovement(
      metricKey: (json['metric_key'] as String?) ?? 'overall_score',
      priority: (json['priority'] as String?) ?? 'medium',
      finding:
          (json['finding'] as String?) ?? 'A practice area was identified.',
      evidence: (json['evidence'] as String?) ??
          'The deterministic score report identified this area.',
      whyItMatters: (json['why_it_matters'] as String?) ??
          'This is a useful next target for practice.',
      action: (json['action'] as String?) ??
          'Repeat the exercise slowly and focus on this area.',
      practicePlan: (json['practice_plan'] as String?) ??
          'Repeat a short guided phrase and review the result.',
    );
  }
}

class CoachingFeedback {
  CoachingFeedback({
    required this.sessionId,
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.nextExercises,
    required this.modelUsed,
    this.summary,
    this.promptVersion,
    this.latencyMs,
    this.scoreBreakdown,
    this.detailedImprovements = const <DetailedImprovement>[],
  });

  final String sessionId;
  final double overallScore;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> nextExercises;
  final String? summary;
  final String modelUsed;
  final String? promptVersion;
  final int? latencyMs;
  final FeedbackScoreBreakdown? scoreBreakdown;
  final List<DetailedImprovement> detailedImprovements;

  factory CoachingFeedback.fromJson(Map<String, dynamic> json) {
    return CoachingFeedback(
      sessionId: json['session_id'] as String,
      overallScore: (json['overall_score'] as num).toDouble(),
      strengths: (json['strengths'] as List<dynamic>).cast<String>(),
      improvements: (json['improvements'] as List<dynamic>).cast<String>(),
      nextExercises: (json['next_exercises'] as List<dynamic>).cast<String>(),
      summary: json['summary'] as String?,
      modelUsed: json['model_used'] as String,
      promptVersion: json['prompt_version'] as String?,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      scoreBreakdown: json['score_breakdown'] == null
          ? null
          : FeedbackScoreBreakdown.fromJson(
              json['score_breakdown'] as Map<String, dynamic>,
            ),
      detailedImprovements:
          (json['detailed_improvements'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => DetailedImprovement.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
    );
  }

  CoachingFeedback copyWith({FeedbackScoreBreakdown? scoreBreakdown}) {
    return CoachingFeedback(
      sessionId: sessionId,
      overallScore: overallScore,
      strengths: strengths,
      improvements: improvements,
      nextExercises: nextExercises,
      summary: summary,
      modelUsed: modelUsed,
      promptVersion: promptVersion,
      latencyMs: latencyMs,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      detailedImprovements: detailedImprovements,
    );
  }
}

class FinalizeResponse {
  FinalizeResponse(
      {required this.sessionId,
      required this.status,
      this.feedback,
      this.jobId});

  final String sessionId;
  final String status;
  final CoachingFeedback? feedback;
  final String? jobId;

  factory FinalizeResponse.fromJson(Map<String, dynamic> json) {
    return FinalizeResponse(
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      feedback: json['feedback'] == null
          ? null
          : CoachingFeedback.fromJson(json['feedback'] as Map<String, dynamic>),
      jobId: json['job_id'] as String?,
    );
  }
}

class TrainingSessionConfig {
  TrainingSessionConfig({
    required this.difficulty,
    required this.key,
    required this.octave,
    this.targetPattern,
    required this.durationSec,
    required this.maxAttempts,
  });

  final String difficulty;
  final String key;
  final int octave;
  final String? targetPattern;
  final int durationSec;
  final int maxAttempts;

  factory TrainingSessionConfig.fromJson(Map<String, dynamic> json) {
    return TrainingSessionConfig(
      difficulty: (json['difficulty'] as String?) ?? 'beginner',
      key: (json['key'] as String?) ?? 'C',
      octave: (json['octave'] as num?)?.toInt() ?? 4,
      targetPattern: json['target_pattern'] as String?,
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 20,
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 3,
    );
  }
}

class TrainingRuntimeStage {
  TrainingRuntimeStage({
    required this.stageId,
    required this.title,
    required this.targetLabel,
    required this.instruction,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
  });

  final String stageId;
  final String title;
  final String targetLabel;
  final String instruction;
  final double durationSec;
  final double startSec;
  final double endSec;

  factory TrainingRuntimeStage.fromJson(Map<String, dynamic> json) {
    final targetLabel = (json['target_label'] as String?) ??
        (json['solfege'] as String?) ??
        (json['title'] as String?) ??
        'Target';
    return TrainingRuntimeStage(
      stageId: json['stage_id'] as String,
      title: json['title'] as String,
      targetLabel: targetLabel,
      instruction: json['instruction'] as String,
      durationSec: (json['duration_sec'] as num).toDouble(),
      startSec: (json['start_sec'] as num).toDouble(),
      endSec: (json['end_sec'] as num).toDouble(),
    );
  }
}

class TrainingRuntimePlan {
  TrainingRuntimePlan({
    required this.patternId,
    required this.patternType,
    required this.summary,
    required this.teachingNote,
    required this.difficulty,
    required this.key,
    required this.octave,
    required this.totalDurationSec,
    required this.stages,
  });

  final String patternId;
  final String patternType;
  final String summary;
  final String teachingNote;
  final String difficulty;
  final String key;
  final int octave;
  final int totalDurationSec;
  final List<TrainingRuntimeStage> stages;

  factory TrainingRuntimePlan.fromJson(Map<String, dynamic> json) {
    return TrainingRuntimePlan(
      patternId: json['pattern_id'] as String,
      patternType: json['pattern_type'] as String,
      summary: json['summary'] as String,
      teachingNote: (json['teaching_note'] as String?) ??
          'Follow the guided steps and use the live cue as your next action.',
      difficulty: json['difficulty'] as String,
      key: json['key'] as String,
      octave: (json['octave'] as num).toInt(),
      totalDurationSec: (json['total_duration_sec'] as num).toInt(),
      stages: (json['stages'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) =>
                TrainingRuntimeStage.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class TrainingAttemptMetricSummary {
  TrainingAttemptMetricSummary.voice({
    required this.sampleCount,
    required double this.pitchAccuracy,
    required double this.timingAccuracy,
    required double this.breathControl,
    required double this.pitchStability,
    required double this.vibratoConsistency,
    required double this.noteTransitionSmoothness,
    this.evidence,
    this.overallScore,
  })  : metricMode = 'voice',
        phaseCompletionRate = null,
        paceAdherence = null,
        cycleConsistency = null,
        completionRate = null,
        interruptionCount = null;

  TrainingAttemptMetricSummary.breathing({
    required this.sampleCount,
    required double this.phaseCompletionRate,
    required double this.paceAdherence,
    required double this.cycleConsistency,
    required double this.completionRate,
    required int this.interruptionCount,
    this.evidence,
    this.overallScore,
  })  : metricMode = 'breathing',
        pitchAccuracy = null,
        timingAccuracy = null,
        breathControl = null,
        pitchStability = null,
        vibratoConsistency = null,
        noteTransitionSmoothness = null;

  final String metricMode;
  final int sampleCount;
  final double? pitchAccuracy;
  final double? timingAccuracy;
  final double? breathControl;
  final double? pitchStability;
  final double? vibratoConsistency;
  final double? noteTransitionSmoothness;
  final double? phaseCompletionRate;
  final double? paceAdherence;
  final double? cycleConsistency;
  final double? completionRate;
  final int? interruptionCount;
  final Map<String, dynamic>? evidence;
  final double? overallScore;

  Map<String, dynamic> toCreateJson() {
    if (metricMode == 'breathing') {
      return {
        'metric_mode': metricMode,
        'sample_count': sampleCount,
        'phase_completion_rate': phaseCompletionRate,
        'pace_adherence': paceAdherence,
        'cycle_consistency': cycleConsistency,
        'completion_rate': completionRate,
        'interruption_count': interruptionCount,
        if (evidence != null) 'evidence': evidence,
      };
    }
    return {
      'metric_mode': metricMode,
      'sample_count': sampleCount,
      'pitch_accuracy': pitchAccuracy,
      'timing_accuracy': timingAccuracy,
      'breath_control': breathControl,
      'pitch_stability': pitchStability,
      'vibrato_consistency': vibratoConsistency,
      'note_transition_smoothness': noteTransitionSmoothness,
      if (evidence != null) 'evidence': evidence,
    };
  }

  factory TrainingAttemptMetricSummary.fromJson(Map<String, dynamic> json) {
    final metricMode = (json['metric_mode'] as String?) ??
        (json.containsKey('phase_completion_rate') ? 'breathing' : 'voice');
    if (metricMode == 'breathing') {
      return TrainingAttemptMetricSummary.breathing(
        sampleCount: (json['sample_count'] as num).toInt(),
        phaseCompletionRate: (json['phase_completion_rate'] as num).toDouble(),
        paceAdherence: (json['pace_adherence'] as num).toDouble(),
        cycleConsistency: (json['cycle_consistency'] as num).toDouble(),
        completionRate: (json['completion_rate'] as num).toDouble(),
        interruptionCount: (json['interruption_count'] as num?)?.toInt() ?? 0,
        evidence: _mapFromJson(json['evidence']),
        overallScore: (json['overall_score'] as num?)?.toDouble(),
      );
    }
    return TrainingAttemptMetricSummary.voice(
      sampleCount: (json['sample_count'] as num).toInt(),
      pitchAccuracy: (json['pitch_accuracy'] as num).toDouble(),
      timingAccuracy: (json['timing_accuracy'] as num).toDouble(),
      breathControl: (json['breath_control'] as num).toDouble(),
      pitchStability: (json['pitch_stability'] as num).toDouble(),
      vibratoConsistency: (json['vibrato_consistency'] as num).toDouble(),
      noteTransitionSmoothness:
          (json['note_transition_smoothness'] as num).toDouble(),
      evidence: _mapFromJson(json['evidence']),
      overallScore: (json['overall_score'] as num?)?.toDouble(),
    );
  }
}

Map<String, dynamic>? _mapFromJson(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

class TrainingAttemptScoreBreakdown {
  TrainingAttemptScoreBreakdown({
    required this.focusMetrics,
    required this.metricScores,
    required this.weightedComponents,
    this.scoringVersion = 'unknown',
    this.sampleCount = 0,
    this.evidenceQuality = 'unknown',
    this.recordingEvidence = const <String, dynamic>{},
    this.metricDetails = const <String, FeedbackMetricDetail>{},
    this.segments = const <FeedbackSegmentEvidence>[],
  });

  final List<String> focusMetrics;
  final Map<String, double> metricScores;
  final Map<String, double> weightedComponents;
  final String scoringVersion;
  final int sampleCount;
  final String evidenceQuality;
  final Map<String, dynamic> recordingEvidence;
  final Map<String, FeedbackMetricDetail> metricDetails;
  final List<FeedbackSegmentEvidence> segments;

  factory TrainingAttemptScoreBreakdown.fromJson(Map<String, dynamic> json) {
    final rawMetricScores =
        json['metric_scores'] as Map<String, dynamic>? ?? const {};
    final rawWeighted =
        json['weighted_components'] as Map<String, dynamic>? ?? const {};
    final rawMetricDetails =
        _mapFromJson(json['metric_details']) ?? const <String, dynamic>{};
    final rawSegments = json['segments'] as List<dynamic>? ?? const <dynamic>[];
    return TrainingAttemptScoreBreakdown(
      focusMetrics:
          (json['focus_metrics'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item as String)
              .toList(),
      metricScores: rawMetricScores.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      weightedComponents: rawWeighted.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      scoringVersion: (json['scoring_version'] as String?) ?? 'unknown',
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      evidenceQuality: (json['evidence_quality'] as String?) ?? 'unknown',
      recordingEvidence:
          _mapFromJson(json['recording_evidence']) ?? const <String, dynamic>{},
      metricDetails: rawMetricDetails.map(
        (key, value) => MapEntry(
          key,
          FeedbackMetricDetail.fromJson(
            value is Map ? Map<String, dynamic>.from(value) : const {},
          ),
        ),
      ),
      segments: rawSegments
          .whereType<Map>()
          .map(
            (item) => FeedbackSegmentEvidence.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class TrainingAttempt {
  TrainingAttempt({
    required this.attemptId,
    required this.attemptIndex,
    required this.difficulty,
    required this.durationSec,
    required this.score,
    required this.metricSummary,
    required this.scoreBreakdown,
    required this.strongestMetric,
    required this.weakestMetric,
    required this.passedThreshold,
    required this.savedAt,
    required this.isBest,
  });

  final String attemptId;
  final int attemptIndex;
  final String difficulty;
  final int durationSec;
  final double score;
  final TrainingAttemptMetricSummary metricSummary;
  final TrainingAttemptScoreBreakdown? scoreBreakdown;
  final String? strongestMetric;
  final String? weakestMetric;
  final bool? passedThreshold;
  final int savedAt;
  final bool isBest;

  factory TrainingAttempt.fromJson(Map<String, dynamic> json) {
    return TrainingAttempt(
      attemptId: json['attempt_id'] as String,
      attemptIndex: (json['attempt_index'] as num).toInt(),
      difficulty: json['difficulty'] as String,
      durationSec: (json['duration_sec'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      metricSummary: TrainingAttemptMetricSummary.fromJson(
        json['metric_summary'] as Map<String, dynamic>,
      ),
      scoreBreakdown: json['score_breakdown'] == null
          ? null
          : TrainingAttemptScoreBreakdown.fromJson(
              json['score_breakdown'] as Map<String, dynamic>,
            ),
      strongestMetric: json['strongest_metric'] as String?,
      weakestMetric: json['weakest_metric'] as String?,
      passedThreshold: json['passed_threshold'] as bool?,
      savedAt: (json['saved_at'] as num).toInt(),
      isBest: json['is_best'] as bool,
    );
  }
}

class TrainingAttemptSavedResponse {
  TrainingAttemptSavedResponse({
    required this.sessionId,
    required this.attempt,
    required this.selectedBestAttemptId,
    required this.bestAttemptScore,
  });

  final String sessionId;
  final TrainingAttempt attempt;
  final String selectedBestAttemptId;
  final double bestAttemptScore;

  factory TrainingAttemptSavedResponse.fromJson(Map<String, dynamic> json) {
    return TrainingAttemptSavedResponse(
      sessionId: json['session_id'] as String,
      attempt:
          TrainingAttempt.fromJson(json['attempt'] as Map<String, dynamic>),
      selectedBestAttemptId: json['selected_best_attempt_id'] as String,
      bestAttemptScore: (json['best_attempt_score'] as num).toDouble(),
    );
  }
}

class AIJob {
  AIJob({
    required this.jobId,
    required this.sessionId,
    required this.state,
    required this.attempt,
    required this.maxAttempts,
    required this.queuedAt,
    required this.updatedAt,
    required this.mode,
    required this.exerciseType,
    this.startedAt,
    this.completedAt,
    this.lastError,
  });

  final String jobId;
  final String sessionId;
  final String state;
  final int attempt;
  final int maxAttempts;
  final int queuedAt;
  final int updatedAt;
  final int? startedAt;
  final int? completedAt;
  final String? lastError;
  final String mode;
  final String exerciseType;

  bool get isTerminal => state == 'completed' || state == 'failed';

  factory AIJob.fromJson(Map<String, dynamic> json) {
    return AIJob(
      jobId: json['job_id'] as String,
      sessionId: json['session_id'] as String,
      state: json['state'] as String,
      attempt: json['attempt'] as int,
      maxAttempts: json['max_attempts'] as int,
      queuedAt: json['queued_at'] as int,
      updatedAt: json['updated_at'] as int,
      startedAt: json['started_at'] as int?,
      completedAt: json['completed_at'] as int?,
      lastError: json['last_error'] as String?,
      mode: json['mode'] as String,
      exerciseType: json['exercise_type'] as String,
    );
  }
}

class SessionDetailsResponse {
  SessionDetailsResponse({
    required this.sessionId,
    required this.userId,
    required this.mode,
    required this.exerciseType,
    required this.status,
    this.overallScore,
    this.feedback,
    this.failureReason,
    this.aiJob,
    this.categoryId,
    this.exerciseId,
    this.exerciseSpec,
    this.trainingConfig,
    this.runtimePlan,
    this.selectedBestAttemptId,
    this.bestAttemptScore,
    this.attempts,
    this.createdAt,
    this.completedAt,
  });

  final String sessionId;
  final String userId;
  final String mode;
  final String exerciseType;
  final String status;
  final double? overallScore;
  final CoachingFeedback? feedback;
  final String? failureReason;
  final AIJob? aiJob;
  final String? categoryId;
  final String? exerciseId;
  final TrainingExercise? exerciseSpec;
  final TrainingSessionConfig? trainingConfig;
  final TrainingRuntimePlan? runtimePlan;
  final String? selectedBestAttemptId;
  final double? bestAttemptScore;
  final List<TrainingAttempt>? attempts;
  final int? createdAt;
  final int? completedAt;

  CoachingFeedback? get feedbackForDisplay {
    final currentFeedback = feedback;
    if (currentFeedback == null || currentFeedback.scoreBreakdown != null) {
      return currentFeedback;
    }

    final savedAttempts = attempts ?? const <TrainingAttempt>[];
    TrainingAttempt? bestAttempt;
    for (final attempt in savedAttempts) {
      if (attempt.isBest) {
        bestAttempt = attempt;
        break;
      }
    }
    bestAttempt ??= savedAttempts.isEmpty ? null : savedAttempts.first;

    final derivedBreakdown = bestAttempt == null
        ? null
        : FeedbackScoreBreakdown.fromTrainingAttempt(bestAttempt);
    return derivedBreakdown == null
        ? currentFeedback
        : currentFeedback.copyWith(scoreBreakdown: derivedBreakdown);
  }

  factory SessionDetailsResponse.fromJson(Map<String, dynamic> json) {
    return SessionDetailsResponse(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      mode: json['mode'] as String,
      exerciseType: json['exercise_type'] as String,
      status: json['status'] as String,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      feedback: json['feedback'] == null
          ? null
          : CoachingFeedback.fromJson(json['feedback'] as Map<String, dynamic>),
      failureReason: json['failure_reason'] as String?,
      aiJob: json['ai_job'] == null
          ? null
          : AIJob.fromJson(json['ai_job'] as Map<String, dynamic>),
      categoryId: json['category_id'] as String?,
      exerciseId: json['exercise_id'] as String?,
      exerciseSpec: json['exercise_spec'] == null
          ? null
          : TrainingExercise.fromJson(
              json['exercise_spec'] as Map<String, dynamic>,
            ),
      trainingConfig: json['training_config'] == null
          ? null
          : TrainingSessionConfig.fromJson(
              json['training_config'] as Map<String, dynamic>,
            ),
      runtimePlan: json['runtime_plan'] == null
          ? null
          : TrainingRuntimePlan.fromJson(
              json['runtime_plan'] as Map<String, dynamic>,
            ),
      selectedBestAttemptId: json['selected_best_attempt_id'] as String?,
      bestAttemptScore: (json['best_attempt_score'] as num?)?.toDouble(),
      attempts: (json['attempts'] as List<dynamic>?)
          ?.map(
              (item) => TrainingAttempt.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: (json['created_at'] as num?)?.toInt() ??
          (json['saved_at'] as num?)?.toInt() ??
          (json['updated_at'] as num?)?.toInt(),
      completedAt: (json['completed_at'] as num?)?.toInt(),
    );
  }
}
