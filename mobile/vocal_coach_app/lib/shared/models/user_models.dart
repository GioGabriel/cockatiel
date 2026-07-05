class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
  });

  final String uid;
  final String email;
  final String name;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
    );
  }
}

enum AccessTier { guest, registered, premium }

AccessTier accessTierFromString(String value) {
  switch (value) {
    case 'premium':
      return AccessTier.premium;
    case 'registered':
      return AccessTier.registered;
    default:
      return AccessTier.guest;
  }
}

String accessTierToString(AccessTier tier) {
  switch (tier) {
    case AccessTier.guest:
      return 'guest';
    case AccessTier.registered:
      return 'registered';
    case AccessTier.premium:
      return 'premium';
  }
}

enum VocalRange { soprano, mezzoSoprano, alto, tenor, baritone, bass }

VocalRange vocalRangeFromString(String value) {
  switch (value) {
    case 'soprano':
      return VocalRange.soprano;
    case 'mezzo-soprano':
      return VocalRange.mezzoSoprano;
    case 'alto':
      return VocalRange.alto;
    case 'tenor':
      return VocalRange.tenor;
    case 'baritone':
      return VocalRange.baritone;
    case 'bass':
      return VocalRange.bass;
    default:
      return VocalRange.tenor;
  }
}

String vocalRangeToString(VocalRange range) {
  switch (range) {
    case VocalRange.soprano:
      return 'soprano';
    case VocalRange.mezzoSoprano:
      return 'mezzo-soprano';
    case VocalRange.alto:
      return 'alto';
    case VocalRange.tenor:
      return 'tenor';
    case VocalRange.baritone:
      return 'baritone';
    case VocalRange.bass:
      return 'bass';
  }
}

enum TrainingGoal {
  pitchImprovement,
  breathControl,
  toneQuality,
  rangeExtension,
  generalSkillBuilding,
}

TrainingGoal trainingGoalFromString(String value) {
  switch (value) {
    case 'pitch_improvement':
      return TrainingGoal.pitchImprovement;
    case 'breath_control':
      return TrainingGoal.breathControl;
    case 'tone_quality':
      return TrainingGoal.toneQuality;
    case 'range_extension':
      return TrainingGoal.rangeExtension;
    default:
      return TrainingGoal.generalSkillBuilding;
  }
}

String trainingGoalToString(TrainingGoal goal) {
  switch (goal) {
    case TrainingGoal.pitchImprovement:
      return 'pitch_improvement';
    case TrainingGoal.breathControl:
      return 'breath_control';
    case TrainingGoal.toneQuality:
      return 'tone_quality';
    case TrainingGoal.rangeExtension:
      return 'range_extension';
    case TrainingGoal.generalSkillBuilding:
      return 'general_skill_building';
  }
}

class VocalPreferences {
  final VocalRange vocalRange;
  final List<String> preferredCategories;
  final TrainingGoal trainingGoal;

  const VocalPreferences({
    required this.vocalRange,
    required this.preferredCategories,
    required this.trainingGoal,
  });

  factory VocalPreferences.fromJson(Map<String, dynamic> json) {
    return VocalPreferences(
      vocalRange: vocalRangeFromString(json['vocal_range'] as String),
      preferredCategories: List<String>.from(
        json['preferred_categories'] as List,
      ),
      trainingGoal: trainingGoalFromString(json['training_goal'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'vocal_range': vocalRangeToString(vocalRange),
    'preferred_categories': preferredCategories,
    'training_goal': trainingGoalToString(trainingGoal),
  };
}

class VocalPreferencesUpdate {
  final VocalRange? vocalRange;
  final List<String>? preferredCategories;
  final TrainingGoal? trainingGoal;

  const VocalPreferencesUpdate({
    this.vocalRange,
    this.preferredCategories,
    this.trainingGoal,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (vocalRange != null) {
      map['vocal_range'] = vocalRangeToString(vocalRange!);
    }
    if (preferredCategories != null) {
      map['preferred_categories'] = preferredCategories;
    }
    if (trainingGoal != null) {
      map['training_goal'] = trainingGoalToString(trainingGoal!);
    }
    return map;
  }
}

class UserProfileFull {
  final String uid;
  final String email;
  final String name;
  final AccessTier accessTier;
  final VocalPreferences? vocalPreferences;
  final int? premiumExpiresAt;

  const UserProfileFull({
    required this.uid,
    required this.email,
    required this.name,
    required this.accessTier,
    this.vocalPreferences,
    this.premiumExpiresAt,
  });

  factory UserProfileFull.fromJson(Map<String, dynamic> json) {
    return UserProfileFull(
      uid: json['uid'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      accessTier: accessTierFromString(json['access_tier'] as String),
      vocalPreferences: json['vocal_preferences'] != null
          ? VocalPreferences.fromJson(
              json['vocal_preferences'] as Map<String, dynamic>,
            )
          : null,
      premiumExpiresAt: json['premium_expires_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'name': name,
    'access_tier': accessTierToString(accessTier),
    'vocal_preferences': vocalPreferences?.toJson(),
    'premium_expires_at': premiumExpiresAt,
  };
}
