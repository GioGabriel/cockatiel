import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/models/karaoke_models.dart';

void main() {
  group('MelodyNote', () {
    final Map<String, dynamic> sampleJson = {
      'note': 'C4',
      'start_beat': 1.0,
      'duration_beats': 2.5,
    };

    test('fromJson parses correctly', () {
      final note = MelodyNote.fromJson(sampleJson);
      expect(note.note, 'C4');
      expect(note.startBeat, 1.0);
      expect(note.durationBeats, 2.5);
    });

    test('toJson serializes correctly', () {
      const note = MelodyNote(
        note: 'C4',
        startBeat: 1.0,
        durationBeats: 2.5,
      );
      expect(note.toJson(), sampleJson);
    });
  });

  group('KaraokeDrill', () {
    final Map<String, dynamic> sampleJson = {
      'drill_id': 'drill_1',
      'title': 'Vocal Warmup',
      'style_category': 'Pop',
      'difficulty': 'beginner',
      'duration_sec': 60,
      'tempo_bpm': 120,
      'vocal_range': {'min': 'C3', 'max': 'C5'},
      'objective': 'Warm up',
      'performance_tips': ['Breathe', 'Relax'],
      'melody_reference': [
        {'note': 'C4', 'start_beat': 1.0, 'duration_beats': 1.0},
      ],
    };

    test('fromJson parses correctly', () {
      final drill = KaraokeDrill.fromJson(sampleJson);
      expect(drill.drillId, 'drill_1');
      expect(drill.title, 'Vocal Warmup');
      expect(drill.vocalRange['min'], 'C3');
      expect(drill.performanceTips, ['Breathe', 'Relax']);
      expect(drill.melodyReference.length, 1);
      expect(drill.melodyReference.first.note, 'C4');
    });

    test('toJson serializes correctly', () {
      const drill = KaraokeDrill(
        drillId: 'drill_1',
        title: 'Vocal Warmup',
        styleCategory: 'Pop',
        difficulty: 'beginner',
        durationSec: 60,
        tempoBpm: 120,
        vocalRange: {'min': 'C3', 'max': 'C5'},
        objective: 'Warm up',
        performanceTips: ['Breathe', 'Relax'],
        melodyReference: [
          MelodyNote(note: 'C4', startBeat: 1.0, durationBeats: 1.0),
        ],
      );
      expect(drill.toJson(), sampleJson);
    });
  });

  group('KaraokeCategory', () {
    final Map<String, dynamic> sampleJson = {
      'category_id': 'cat_1',
      'style_label': 'Pop',
      'description': 'Pop songs',
      'drills': [
        {
          'drill_id': 'drill_1',
          'title': 'Vocal Warmup',
          'style_category': 'Pop',
          'difficulty': 'beginner',
          'duration_sec': 60,
          'tempo_bpm': 120,
          'vocal_range': {'min': 'C3', 'max': 'C5'},
          'objective': 'Warm up',
          'performance_tips': [],
          'melody_reference': [],
        }
      ],
    };

    test('fromJson parses correctly', () {
      final category = KaraokeCategory.fromJson(sampleJson);
      expect(category.categoryId, 'cat_1');
      expect(category.styleLabel, 'Pop');
      expect(category.description, 'Pop songs');
      expect(category.drills.length, 1);
      expect(category.drills.first.drillId, 'drill_1');
    });
  });

  group('KaraokeCatalog', () {
    final Map<String, dynamic> sampleJson = {
      'module_id': 'mod_1',
      'title': 'Catalog',
      'description': 'All songs',
      'categories': [
        {
          'category_id': 'cat_1',
          'style_label': 'Pop',
          'description': 'Pop songs',
          'drills': [],
        }
      ],
    };

    test('fromJson parses correctly', () {
      final catalog = KaraokeCatalog.fromJson(sampleJson);
      expect(catalog.moduleId, 'mod_1');
      expect(catalog.title, 'Catalog');
      expect(catalog.categories.length, 1);
      expect(catalog.categories.first.categoryId, 'cat_1');
    });
  });
}
