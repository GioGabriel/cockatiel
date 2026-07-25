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

class CoachingFeedback {
  CoachingFeedback({
    required this.sessionId,
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.nextExercises,
    required this.modelUsed,
    this.promptVersion,
    this.latencyMs,
  });

  final String sessionId;
  final double overallScore;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> nextExercises;
  final String modelUsed;
  final String? promptVersion;
  final int? latencyMs;

  factory CoachingFeedback.fromJson(Map<String, dynamic> json) {
    return CoachingFeedback(
      sessionId: json['session_id'] as String,
      overallScore: (json['overall_score'] as num).toDouble(),
      strengths: (json['strengths'] as List<dynamic>).cast<String>(),
      improvements: (json['improvements'] as List<dynamic>).cast<String>(),
      nextExercises: (json['next_exercises'] as List<dynamic>).cast<String>(),
      modelUsed: json['model_used'] as String,
      promptVersion: json['prompt_version'] as String?,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
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
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 30,
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
  final int durationSec;
  final int startSec;
  final int endSec;

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
      durationSec: (json['duration_sec'] as num).toInt(),
      startSec: (json['start_sec'] as num).toInt(),
      endSec: (json['end_sec'] as num).toInt(),
    );
  }
}

class TrainingRuntimePlan {
  TrainingRuntimePlan({
    required this.patternId,
    required this.patternType,
    required this.summary,
    required this.difficulty,
    required this.key,
    required this.octave,
    required this.totalDurationSec,
    required this.stages,
  });

  final String patternId;
  final String patternType;
  final String summary;
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
      overallScore: (json['overall_score'] as num?)?.toDouble(),
    );
  }
}

class TrainingAttemptScoreBreakdown {
  TrainingAttemptScoreBreakdown({
    required this.focusMetrics,
    required this.metricScores,
    required this.weightedComponents,
  });

  final List<String> focusMetrics;
  final Map<String, double> metricScores;
  final Map<String, double> weightedComponents;

  factory TrainingAttemptScoreBreakdown.fromJson(Map<String, dynamic> json) {
    final rawMetricScores =
        json['metric_scores'] as Map<String, dynamic>? ?? const {};
    final rawWeighted =
        json['weighted_components'] as Map<String, dynamic>? ?? const {};
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
      createdAt: (json['created_at'] as num?)?.toInt() ?? (json['saved_at'] as num?)?.toInt() ?? (json['updated_at'] as num?)?.toInt(),
      completedAt: (json['completed_at'] as num?)?.toInt(),
    );
  }
}
