class TrainingAttemptPolicy {
  TrainingAttemptPolicy({
    required this.maxAttempts,
    required this.durationSecByDifficulty,
  });

  final int maxAttempts;
  final Map<String, int> durationSecByDifficulty;

  factory TrainingAttemptPolicy.fromJson(Map<String, dynamic> json) {
    final raw = (json['duration_sec_by_difficulty'] as Map<String, dynamic>? ??
        const <String, dynamic>{});
    return TrainingAttemptPolicy(
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 3,
      durationSecByDifficulty: raw.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
  }
}

class TrainingSuccessThresholds {
  TrainingSuccessThresholds({
    required this.overallScore,
    required this.metricFloors,
  });

  final double overallScore;
  final Map<String, double> metricFloors;

  factory TrainingSuccessThresholds.fromJson(Map<String, dynamic> json) {
    final rawFloors =
        json['metric_floors'] as Map<String, dynamic>? ?? const {};
    return TrainingSuccessThresholds(
      overallScore: (json['overall_score'] as num).toDouble(),
      metricFloors: rawFloors.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }
}

class TrainingCoachCues {
  TrainingCoachCues({
    required this.ready,
    required this.tooSoft,
    required this.onPitch,
    required this.lowPitch,
    required this.highPitch,
  });

  final String ready;
  final String tooSoft;
  final String onPitch;
  final String lowPitch;
  final String highPitch;

  factory TrainingCoachCues.fromJson(Map<String, dynamic> json) {
    return TrainingCoachCues(
      ready: json['ready'] as String,
      tooSoft: json['too_soft'] as String,
      onPitch: json['on_pitch'] as String,
      lowPitch: json['low_pitch'] as String,
      highPitch: json['high_pitch'] as String,
    );
  }
}

class TrainingPatternStageTemplate {
  TrainingPatternStageTemplate({
    required this.stageId,
    required this.title,
    required this.targetLabel,
    required this.instruction,
    required this.beats,
  });

  final String stageId;
  final String title;
  final String targetLabel;
  final String instruction;
  final int beats;

  factory TrainingPatternStageTemplate.fromJson(Map<String, dynamic> json) {
    final targetLabel = (json['target_label'] as String?) ??
        (json['solfege'] as String?) ??
        (json['title'] as String?) ??
        'Target';
    return TrainingPatternStageTemplate(
      stageId: json['stage_id'] as String,
      title: json['title'] as String,
      targetLabel: targetLabel,
      instruction: json['instruction'] as String,
      beats: (json['beats'] as num).toInt(),
    );
  }
}

class TrainingPatternTemplate {
  TrainingPatternTemplate({
    required this.patternId,
    required this.patternType,
    required this.summary,
    required this.stages,
  });

  final String patternId;
  final String patternType;
  final String summary;
  final List<TrainingPatternStageTemplate> stages;

  factory TrainingPatternTemplate.fromJson(Map<String, dynamic> json) {
    return TrainingPatternTemplate(
      patternId: json['pattern_id'] as String,
      patternType: json['pattern_type'] as String,
      summary: json['summary'] as String,
      stages: (json['stages'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => TrainingPatternStageTemplate.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class TrainingExercise {
  TrainingExercise({
    required this.exerciseId,
    required this.name,
    required this.description,
    required this.objective,
    required this.whatYouDo,
    required this.requiresMicrophone,
    required this.exerciseMode,
    required this.instructions,
    required this.aiFocus,
    required this.defaultDifficulty,
    required this.recommendedOrder,
    required this.focusMetrics,
    required this.metricWeights,
    required this.successThresholds,
    required this.coachCues,
    required this.patternsByDifficulty,
  });

  final String exerciseId;
  final String name;
  final String description;
  final String objective;
  final String whatYouDo;
  final bool requiresMicrophone;
  final String exerciseMode;
  final List<String> instructions;
  final String aiFocus;
  final String defaultDifficulty;
  final int recommendedOrder;
  final List<String> focusMetrics;
  final Map<String, double> metricWeights;
  final TrainingSuccessThresholds successThresholds;
  final TrainingCoachCues coachCues;
  final Map<String, TrainingPatternTemplate> patternsByDifficulty;

  factory TrainingExercise.fromJson(Map<String, dynamic> json) {
    final rawWeights =
        json['metric_weights'] as Map<String, dynamic>? ?? const {};
    final rawPatterns =
        json['patterns_by_difficulty'] as Map<String, dynamic>? ?? const {};
    return TrainingExercise(
      exerciseId: json['exercise_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      objective: json['objective'] as String,
      whatYouDo:
          json['what_you_do'] as String? ?? json['description'] as String,
      requiresMicrophone: json['requires_microphone'] as bool? ?? true,
      exerciseMode: json['exercise_mode'] as String? ?? 'voice',
      instructions:
          (json['instructions'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item as String)
              .toList(),
      aiFocus: json['ai_focus'] as String,
      defaultDifficulty: json['default_difficulty'] as String,
      recommendedOrder: (json['recommended_order'] as num).toInt(),
      focusMetrics: (json['focus_metrics'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      metricWeights: rawWeights.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      successThresholds: TrainingSuccessThresholds.fromJson(
        json['success_thresholds'] as Map<String, dynamic>,
      ),
      coachCues: TrainingCoachCues.fromJson(
        json['coach_cues'] as Map<String, dynamic>,
      ),
      patternsByDifficulty: rawPatterns.map(
        (key, value) => MapEntry(
          key,
          TrainingPatternTemplate.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }
}

class TrainingCategory {
  TrainingCategory({
    required this.categoryId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.exercises,
  });

  final String categoryId;
  final String title;
  final String subtitle;
  final String description;
  final List<TrainingExercise> exercises;

  factory TrainingCategory.fromJson(Map<String, dynamic> json) {
    return TrainingCategory(
      categoryId: json['category_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      exercises: (json['exercises'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => TrainingExercise.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class TrainingCatalog {
  TrainingCatalog({
    required this.moduleId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.attemptPolicy,
    required this.categories,
  });

  final String moduleId;
  final String title;
  final String subtitle;
  final String description;
  final TrainingAttemptPolicy attemptPolicy;
  final List<TrainingCategory> categories;

  factory TrainingCatalog.fromJson(Map<String, dynamic> json) {
    return TrainingCatalog(
      moduleId: json['module_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      attemptPolicy: TrainingAttemptPolicy.fromJson(
        json['attempt_policy'] as Map<String, dynamic>,
      ),
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => TrainingCategory.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class TrainingExerciseProgress {
  TrainingExerciseProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.categoryId,
    required this.sessionsCompleted,
    required this.avgScore,
    required this.bestScore,
    required this.lastScore,
    required this.lastCompletedAt,
  });

  final String exerciseId;
  final String exerciseName;
  final String categoryId;
  final int sessionsCompleted;
  final double avgScore;
  final double bestScore;
  final double lastScore;
  final int lastCompletedAt;

  factory TrainingExerciseProgress.fromJson(Map<String, dynamic> json) {
    return TrainingExerciseProgress(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      categoryId: json['category_id'] as String,
      sessionsCompleted: (json['sessions_completed'] as num).toInt(),
      avgScore: (json['avg_score'] as num).toDouble(),
      bestScore: (json['best_score'] as num).toDouble(),
      lastScore: (json['last_score'] as num).toDouble(),
      lastCompletedAt: (json['last_completed_at'] as num).toInt(),
    );
  }
}

class TrainingProgress {
  TrainingProgress({
    required this.userId,
    required this.generatedAt,
    required this.items,
  });

  final String userId;
  final int generatedAt;
  final List<TrainingExerciseProgress> items;

  factory TrainingProgress.fromJson(Map<String, dynamic> json) {
    return TrainingProgress(
      userId: json['user_id'] as String,
      generatedAt: (json['generated_at'] as num).toInt(),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => TrainingExerciseProgress.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class TrainingRecommendation {
  TrainingRecommendation({
    required this.exerciseId,
    required this.exerciseName,
    required this.categoryId,
    required this.reason,
    required this.priority,
  });

  final String exerciseId;
  final String exerciseName;
  final String categoryId;
  final String reason;
  final double priority;

  factory TrainingRecommendation.fromJson(Map<String, dynamic> json) {
    return TrainingRecommendation(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      categoryId: json['category_id'] as String,
      reason: json['reason'] as String,
      priority: (json['priority'] as num).toDouble(),
    );
  }
}

class TrainingRecommendations {
  TrainingRecommendations({
    required this.userId,
    required this.generatedAt,
    required this.items,
  });

  final String userId;
  final int generatedAt;
  final List<TrainingRecommendation> items;

  factory TrainingRecommendations.fromJson(Map<String, dynamic> json) {
    return TrainingRecommendations(
      userId: json['user_id'] as String,
      generatedAt: (json['generated_at'] as num).toInt(),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) =>
                TrainingRecommendation.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
