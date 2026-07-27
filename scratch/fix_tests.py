import re

file_path = r'g:\cockatiel\mobile\vocal_coach_app\test\shared\models\karaoke_models_test.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# For the first sampleJson in KaraokeDrill
content = content.replace(
'''      'performance_tips': ['Breathe', 'Relax'],
      'melody_reference': [
        {'note': 'C4', 'start_beat': 1.0, 'duration_beats': 1.0},
      ],''',
'''      'performance_tips': ['Breathe', 'Relax'],
      'melody_reference': [
        {'note': 'C4', 'start_beat': 1.0, 'duration_beats': 1.0},
      ],
      'instrumental_url': '',
      'pitch_map_url': '',
      'artist_name': '',
      'cover_url': '','''
)

# For the second sampleJson in KaraokeCategory
content = content.replace(
'''          'objective': 'Warm up',
          'performance_tips': [],
          'melody_reference': [],''',
'''          'objective': 'Warm up',
          'performance_tips': [],
          'melody_reference': [],
          'instrumental_url': '',
          'pitch_map_url': '',
          'artist_name': '',
          'cover_url': '','''
)

# For the third sampleJson in KaraokeCatalog
content = content.replace(
'''              'objective': 'Warm up',
              'performance_tips': [],
              'melody_reference': [],''',
'''              'objective': 'Warm up',
              'performance_tips': [],
              'melody_reference': [],
              'instrumental_url': '',
              'pitch_map_url': '',
              'artist_name': '',
              'cover_url': '','''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Tests fixed!")
