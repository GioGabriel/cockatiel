class MelodyNote {
  final String note;
  final double startBeat;
  final double durationBeats;

  const MelodyNote({
    required this.note,
    required this.startBeat,
    required this.durationBeats,
  });

  factory MelodyNote.fromJson(Map<String, dynamic> json) {
    return MelodyNote(
      note: json['note'] as String,
      startBeat: (json['start_beat'] as num).toDouble(),
      durationBeats: (json['duration_beats'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'note': note,
    'start_beat': startBeat,
    'duration_beats': durationBeats,
  };
}

class KaraokeDrill {
  final String drillId;
  final String title;
  final String styleCategory;
  final String difficulty;
  final int durationSec;
  final int tempoBpm;
  final Map<String, String> vocalRange;
  final String objective;
  final List<String> performanceTips;
  final List<MelodyNote> melodyReference;

  const KaraokeDrill({
    required this.drillId,
    required this.title,
    required this.styleCategory,
    required this.difficulty,
    required this.durationSec,
    required this.tempoBpm,
    required this.vocalRange,
    required this.objective,
    required this.performanceTips,
    required this.melodyReference,
  });

  factory KaraokeDrill.fromJson(Map<String, dynamic> json) {
    return KaraokeDrill(
      drillId: json['drill_id'] as String,
      title: json['title'] as String,
      styleCategory: json['style_category'] as String,
      difficulty: json['difficulty'] as String,
      durationSec: json['duration_sec'] as int,
      tempoBpm: json['tempo_bpm'] as int,
      vocalRange: Map<String, String>.from(json['vocal_range'] as Map),
      objective: json['objective'] as String,
      performanceTips:
          List<String>.from(json['performance_tips'] as List),
      melodyReference: (json['melody_reference'] as List)
          .map(
            (e) => MelodyNote.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'drill_id': drillId,
    'title': title,
    'style_category': styleCategory,
    'difficulty': difficulty,
    'duration_sec': durationSec,
    'tempo_bpm': tempoBpm,
    'vocal_range': vocalRange,
    'objective': objective,
    'performance_tips': performanceTips,
    'melody_reference':
        melodyReference.map((e) => e.toJson()).toList(),
  };
}

class KaraokeCategory {
  final String categoryId;
  final String styleLabel;
  final String description;
  final List<KaraokeDrill> drills;

  const KaraokeCategory({
    required this.categoryId,
    required this.styleLabel,
    required this.description,
    required this.drills,
  });

  factory KaraokeCategory.fromJson(Map<String, dynamic> json) {
    return KaraokeCategory(
      categoryId: json['category_id'] as String,
      styleLabel: json['style_label'] as String,
      description: json['description'] as String,
      drills: (json['drills'] as List)
          .map(
            (e) => KaraokeDrill.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class KaraokeCatalog {
  final String moduleId;
  final String title;
  final String description;
  final List<KaraokeCategory> categories;

  const KaraokeCatalog({
    required this.moduleId,
    required this.title,
    required this.description,
    required this.categories,
  });

  factory KaraokeCatalog.fromJson(Map<String, dynamic> json) {
    return KaraokeCatalog(
      moduleId: json['module_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      categories: (json['categories'] as List)
          .map(
            (e) =>
                KaraokeCategory.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
