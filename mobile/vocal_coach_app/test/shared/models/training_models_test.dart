import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/models/training_models.dart';

void main() {
  group('TrainingAttemptPolicy', () {
    test('fromJson parses correctly', () {
      final json = {
        'max_attempts': 5,
        'duration_sec_by_difficulty': {'beginner': 60, 'advanced': 120}
      };
      final policy = TrainingAttemptPolicy.fromJson(json);
      expect(policy.maxAttempts, 5);
      expect(policy.durationSecByDifficulty['beginner'], 60);
      expect(policy.durationSecByDifficulty['advanced'], 120);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};
      final policy = TrainingAttemptPolicy.fromJson(json);
      expect(policy.maxAttempts, 3);
      expect(policy.durationSecByDifficulty.isEmpty, true);
    });
  });

  group('TrainingSuccessThresholds', () {
    test('fromJson parses correctly', () {
      final json = {
        'overall_score': 80.5,
        'metric_floors': {'pitch': 85.0}
      };
      final thresholds = TrainingSuccessThresholds.fromJson(json);
      expect(thresholds.overallScore, 80.5);
      expect(thresholds.metricFloors['pitch'], 85.0);
    });
  });

  group('TrainingCoachCues', () {
    test('fromJson parses correctly', () {
      final json = {
        'ready': 'Ready?',
        'too_soft': 'Louder!',
        'on_pitch': 'Great!',
        'low_pitch': 'Higher!',
        'high_pitch': 'Lower!',
      };
      final cues = TrainingCoachCues.fromJson(json);
      expect(cues.ready, 'Ready?');
      expect(cues.tooSoft, 'Louder!');
      expect(cues.onPitch, 'Great!');
      expect(cues.lowPitch, 'Higher!');
      expect(cues.highPitch, 'Lower!');
    });
  });

  group('TrainingPatternStageTemplate', () {
    test('fromJson parses correctly with target_label', () {
      final json = {
        'stage_id': 's1',
        'title': 'Stage 1',
        'target_label': 'Target 1',
        'instruction': 'Do this',
        'beats': 4,
      };
      final stage = TrainingPatternStageTemplate.fromJson(json);
      expect(stage.stageId, 's1');
      expect(stage.targetLabel, 'Target 1');
      expect(stage.beats, 4);
    });

    test('fromJson falls back to solfege', () {
      final json = {
        'stage_id': 's1',
        'title': 'Stage 1',
        'solfege': 'Do',
        'instruction': 'Do this',
        'beats': 4,
      };
      final stage = TrainingPatternStageTemplate.fromJson(json);
      expect(stage.targetLabel, 'Do');
    });

    test('fromJson falls back to title', () {
      final json = {
        'stage_id': 's1',
        'title': 'Stage 1',
        'instruction': 'Do this',
        'beats': 4,
      };
      final stage = TrainingPatternStageTemplate.fromJson(json);
      expect(stage.targetLabel, 'Stage 1');
    });
  });

  group('TrainingPatternTemplate', () {
    test('fromJson parses correctly', () {
      final json = {
        'pattern_id': 'p1',
        'pattern_type': 'scale',
        'summary': 'A scale',
        'stages': [
          {
            'stage_id': 's1',
            'title': 'Stage 1',
            'instruction': 'Do this',
            'beats': 4,
          }
        ]
      };
      final pattern = TrainingPatternTemplate.fromJson(json);
      expect(pattern.patternId, 'p1');
      expect(pattern.stages.length, 1);
    });
  });

  group('TrainingExercise', () {
    test('fromJson parses correctly with all defaults', () {
      final json = {
        'exercise_id': 'e1',
        'name': 'Ex 1',
        'description': 'Desc 1',
        'objective': 'Obj 1',
        'ai_focus': 'Focus',
        'default_difficulty': 'easy',
        'recommended_order': 1,
        'success_thresholds': {'overall_score': 80.0, 'metric_floors': <String, dynamic>{}},
        'coach_cues': {
          'ready': '1', 'too_soft': '2', 'on_pitch': '3', 'low_pitch': '4', 'high_pitch': '5'
        },
      };
      final exercise = TrainingExercise.fromJson(json);
      expect(exercise.exerciseId, 'e1');
      expect(exercise.whatYouDo, 'Desc 1'); // defaults to description
      expect(exercise.requiresMicrophone, true);
      expect(exercise.exerciseMode, 'voice');
    });

    test('fromJson parses overrides correctly', () {
      final json = {
        'exercise_id': 'e1',
        'name': 'Ex 1',
        'description': 'Desc 1',
        'objective': 'Obj 1',
        'what_you_do': 'What you do',
        'requires_microphone': false,
        'exercise_mode': 'breathing',
        'instructions': ['Step 1'],
        'ai_focus': 'Focus',
        'default_difficulty': 'easy',
        'recommended_order': 1,
        'focus_metrics': ['m1'],
        'metric_weights': {'m1': 1.0},
        'success_thresholds': {'overall_score': 80.0, 'metric_floors': <String, dynamic>{}},
        'coach_cues': {
          'ready': '1', 'too_soft': '2', 'on_pitch': '3', 'low_pitch': '4', 'high_pitch': '5'
        },
        'patterns_by_difficulty': {
          'easy': {
            'pattern_id': 'p1',
            'pattern_type': 'scale',
            'summary': 'A scale',
            'stages': <dynamic>[]
          }
        }
      };
      final exercise = TrainingExercise.fromJson(json);
      expect(exercise.whatYouDo, 'What you do');
      expect(exercise.requiresMicrophone, false);
      expect(exercise.exerciseMode, 'breathing');
      expect(exercise.instructions, ['Step 1']);
      expect(exercise.patternsByDifficulty.length, 1);
    });
  });

  group('TrainingCategory', () {
    test('fromJson parses correctly', () {
      final json = {
        'category_id': 'cat_1',
        'title': 'Category 1',
        'subtitle': 'Sub',
        'description': 'Desc',
        'exercises': <dynamic>[]
      };
      final cat = TrainingCategory.fromJson(json);
      expect(cat.categoryId, 'cat_1');
      expect(cat.exercises.isEmpty, true);
    });
  });

  group('TrainingCatalog', () {
    test('fromJson parses correctly', () {
      final json = {
        'module_id': 'm1',
        'title': 'Module 1',
        'subtitle': 'Sub',
        'description': 'Desc',
        'attempt_policy': {
           'max_attempts': 3,
        },
        'categories': <dynamic>[]
      };
      final cat = TrainingCatalog.fromJson(json);
      expect(cat.moduleId, 'm1');
      expect(cat.attemptPolicy.maxAttempts, 3);
    });
  });

  group('TrainingExerciseProgress', () {
    test('fromJson parses correctly', () {
      final json = {
        'exercise_id': 'e1',
        'exercise_name': 'Ex 1',
        'category_id': 'c1',
        'sessions_completed': 5,
        'avg_score': 85.0,
        'best_score': 90.0,
        'last_score': 88.0,
        'last_completed_at': 1234567890
      };
      final prog = TrainingExerciseProgress.fromJson(json);
      expect(prog.exerciseId, 'e1');
      expect(prog.avgScore, 85.0);
    });
  });

  group('TrainingProgress', () {
    test('fromJson parses correctly', () {
      final json = {
        'user_id': 'u1',
        'generated_at': 1234567890,
        'items': <dynamic>[]
      };
      final prog = TrainingProgress.fromJson(json);
      expect(prog.userId, 'u1');
      expect(prog.items.isEmpty, true);
    });
  });

  group('TrainingRecommendation', () {
    test('fromJson parses correctly', () {
      final json = {
        'exercise_id': 'e1',
        'exercise_name': 'Ex 1',
        'category_id': 'c1',
        'reason': 'Needs work',
        'priority': 0.8
      };
      final rec = TrainingRecommendation.fromJson(json);
      expect(rec.exerciseId, 'e1');
      expect(rec.priority, 0.8);
    });
  });

  group('TrainingRecommendations', () {
    test('fromJson parses correctly', () {
      final json = {
        'user_id': 'u1',
        'generated_at': 1234567890,
        'items': <dynamic>[]
      };
      final recs = TrainingRecommendations.fromJson(json);
      expect(recs.userId, 'u1');
      expect(recs.items.isEmpty, true);
    });
  });
}
