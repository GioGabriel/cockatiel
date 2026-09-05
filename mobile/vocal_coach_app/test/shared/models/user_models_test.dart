import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/models/user_models.dart';

void main() {
  group('UserProfile', () {
    test('fromJson parses correctly', () {
      final json = {
        'uid': '123',
        'email': 'test@example.com',
        'name': 'John Doe'
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.uid, '123');
      expect(profile.email, 'test@example.com');
      expect(profile.name, 'John Doe');
    });
  });

  group('AccessTier', () {
    test('accessTierFromString', () {
      expect(accessTierFromString('premium'), AccessTier.premium);
      expect(accessTierFromString('registered'), AccessTier.registered);
      expect(accessTierFromString('guest'), AccessTier.guest);
      expect(accessTierFromString('unknown'), AccessTier.guest);
    });

    test('accessTierToString', () {
      expect(accessTierToString(AccessTier.premium), 'premium');
      expect(accessTierToString(AccessTier.registered), 'registered');
      expect(accessTierToString(AccessTier.guest), 'guest');
    });
  });

  group('VocalRange', () {
    test('vocalRangeFromString', () {
      expect(vocalRangeFromString('soprano'), VocalRange.soprano);
      expect(vocalRangeFromString('mezzo-soprano'), VocalRange.mezzoSoprano);
      expect(vocalRangeFromString('alto'), VocalRange.alto);
      expect(vocalRangeFromString('tenor'), VocalRange.tenor);
      expect(vocalRangeFromString('baritone'), VocalRange.baritone);
      expect(vocalRangeFromString('bass'), VocalRange.bass);
      expect(vocalRangeFromString('unknown'), VocalRange.tenor); // default
    });

    test('vocalRangeToString', () {
      expect(vocalRangeToString(VocalRange.soprano), 'soprano');
      expect(vocalRangeToString(VocalRange.mezzoSoprano), 'mezzo-soprano');
      expect(vocalRangeToString(VocalRange.alto), 'alto');
      expect(vocalRangeToString(VocalRange.tenor), 'tenor');
      expect(vocalRangeToString(VocalRange.baritone), 'baritone');
      expect(vocalRangeToString(VocalRange.bass), 'bass');
    });
  });

  group('TrainingGoal', () {
    test('trainingGoalFromString', () {
      expect(trainingGoalFromString('pitch_improvement'),
          TrainingGoal.pitchImprovement);
      expect(
          trainingGoalFromString('breath_control'), TrainingGoal.breathControl);
      expect(trainingGoalFromString('tone_quality'), TrainingGoal.toneQuality);
      expect(trainingGoalFromString('range_extension'),
          TrainingGoal.rangeExtension);
      expect(
          trainingGoalFromString('unknown'), TrainingGoal.generalSkillBuilding);
    });

    test('trainingGoalToString', () {
      expect(trainingGoalToString(TrainingGoal.pitchImprovement),
          'pitch_improvement');
      expect(
          trainingGoalToString(TrainingGoal.breathControl), 'breath_control');
      expect(trainingGoalToString(TrainingGoal.toneQuality), 'tone_quality');
      expect(
          trainingGoalToString(TrainingGoal.rangeExtension), 'range_extension');
      expect(trainingGoalToString(TrainingGoal.generalSkillBuilding),
          'general_skill_building');
    });
  });

  group('VocalPreferences', () {
    final Map<String, dynamic> sampleJson = {
      'vocal_range': 'tenor',
      'preferred_categories': ['pop', 'jazz'],
      'training_goal': 'pitch_improvement',
    };

    test('fromJson parses correctly', () {
      final prefs = VocalPreferences.fromJson(sampleJson);
      expect(prefs.vocalRange, VocalRange.tenor);
      expect(prefs.preferredCategories, ['pop', 'jazz']);
      expect(prefs.trainingGoal, TrainingGoal.pitchImprovement);
    });

    test('toJson serializes correctly', () {
      const prefs = VocalPreferences(
        vocalRange: VocalRange.tenor,
        preferredCategories: ['pop', 'jazz'],
        trainingGoal: TrainingGoal.pitchImprovement,
      );
      expect(prefs.toJson(), sampleJson);
    });

    test('round-trips optional voice calibration metadata', () {
      final json = {
        ...sampleJson,
        'voice_calibration': {
          'voice_type': 'tenor',
          'confidence': 0.82,
          'average_frequency_hz': 196.0,
          'lowest_frequency_hz': 130.8,
          'highest_frequency_hz': 392.0,
          'sample_count': 96,
          'calibrated_at_ms': 1760000000000,
        },
      };
      final prefs = VocalPreferences.fromJson(json);

      expect(prefs.voiceCalibration?.voiceType, VocalRange.tenor);
      expect(prefs.voiceCalibration?.confidence, 0.82);
      expect(prefs.voiceCalibration?.sampleCount, 96);
      expect(prefs.toJson(), json);
    });
  });

  group('VocalPreferencesUpdate', () {
    test('toJson with all fields', () {
      const update = VocalPreferencesUpdate(
        vocalRange: VocalRange.alto,
        preferredCategories: ['rock'],
        trainingGoal: TrainingGoal.rangeExtension,
      );
      expect(update.toJson(), {
        'vocal_range': 'alto',
        'preferred_categories': ['rock'],
        'training_goal': 'range_extension',
      });
    });

    test('toJson with no fields', () {
      const update = VocalPreferencesUpdate();
      expect(update.toJson(), {});
    });

    test('toJson includes optional voice calibration metadata', () {
      const update = VocalPreferencesUpdate(
        voiceCalibration: VoiceCalibration(
          voiceType: VocalRange.alto,
          confidence: 0.74,
          averageFrequencyHz: 277.2,
          lowestFrequencyHz: 174.6,
          highestFrequencyHz: 523.3,
          sampleCount: 64,
          calibratedAtMs: 1760000000000,
        ),
      );

      expect(update.toJson()['voice_calibration'], {
        'voice_type': 'alto',
        'confidence': 0.74,
        'average_frequency_hz': 277.2,
        'lowest_frequency_hz': 174.6,
        'highest_frequency_hz': 523.3,
        'sample_count': 64,
        'calibrated_at_ms': 1760000000000,
      });
    });
  });

  group('UserProfileFull', () {
    final Map<String, dynamic> sampleJson = {
      'uid': 'user123',
      'email': 'user@example.com',
      'name': 'Alice',
      'access_tier': 'premium',
      'vocal_preferences': {
        'vocal_range': 'soprano',
        'preferred_categories': ['classical'],
        'training_goal': 'tone_quality',
      },
      'premium_expires_at': 1672531200000,
    };

    test('fromJson parses correctly', () {
      final profile = UserProfileFull.fromJson(sampleJson);
      expect(profile.uid, 'user123');
      expect(profile.email, 'user@example.com');
      expect(profile.name, 'Alice');
      expect(profile.accessTier, AccessTier.premium);
      expect(profile.vocalPreferences?.vocalRange, VocalRange.soprano);
      expect(profile.premiumExpiresAt, 1672531200000);
    });

    test('fromJson parses without optional fields', () {
      final jsonNoOptional = {
        'uid': 'user123',
        'email': 'user@example.com',
        'name': 'Alice',
        'access_tier': 'registered',
      };
      final profile = UserProfileFull.fromJson(jsonNoOptional);
      expect(profile.vocalPreferences, isNull);
      expect(profile.premiumExpiresAt, isNull);
    });

    test('toJson serializes correctly', () {
      const profile = UserProfileFull(
        uid: 'user123',
        email: 'user@example.com',
        name: 'Alice',
        accessTier: AccessTier.premium,
        vocalPreferences: VocalPreferences(
          vocalRange: VocalRange.soprano,
          preferredCategories: ['classical'],
          trainingGoal: TrainingGoal.toneQuality,
        ),
        premiumExpiresAt: 1672531200000,
      );
      expect(profile.toJson(), sampleJson);
    });
  });
}
