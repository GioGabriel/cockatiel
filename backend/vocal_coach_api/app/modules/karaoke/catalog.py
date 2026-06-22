from copy import deepcopy
from typing import Any

_KARAOKE_CATALOG: dict[str, Any] = {
  "module_id": "karaoke",
  "title": "Karaoke Practice",
  "description": "Song-based vocal drills combining entertainment with AI evaluation.",
  "categories": [
    {
      "category_id": "pop_ballad",
      "style_label": "Pop Ballad",
      "description": "Slow-tempo pop songs emphasizing breath control and sustained phrasing.",
      "drills": [
        {
          "drill_id": "pop_breath_control_1",
          "title": "Sustained Phrases Pop Drill",
          "style_category": "Pop Ballad",
          "difficulty": "beginner",
          "duration_sec": 60,
          "tempo_bpm": 72,
          "vocal_range": {"low": "C3", "high": "G4"},
          "objective": "Practice maintaining steady breath support through long pop phrases.",
          "performance_tips": [
            "Focus on smooth onset without breathiness",
            "Keep shoulders relaxed and breathe from the diaphragm",
          ],
          "melody_reference": [
            {"note": "C4", "start_beat": 0.0, "duration_beats": 2.0},
            {"note": "E4", "start_beat": 2.0, "duration_beats": 1.5},
            {"note": "G4", "start_beat": 3.5, "duration_beats": 2.5},
            {"note": "F4", "start_beat": 6.0, "duration_beats": 2.0},
            {"note": "D4", "start_beat": 8.0, "duration_beats": 4.0},
          ],
        },
        {
          "drill_id": "pop_dynamic_control_1",
          "title": "Dynamic Crescendo Ballad",
          "style_category": "Pop Ballad",
          "difficulty": "intermediate",
          "duration_sec": 90,
          "tempo_bpm": 66,
          "vocal_range": {"low": "A3", "high": "A4"},
          "objective": "Build dynamic control by gradually increasing volume across a phrase.",
          "performance_tips": [
            "Start at piano and build smoothly to forte",
            "Maintain pitch stability as volume increases",
            "Reset breath support at each new phrase",
          ],
          "melody_reference": [
            {"note": "A3", "start_beat": 0.0, "duration_beats": 3.0},
            {"note": "C4", "start_beat": 3.0, "duration_beats": 2.0},
            {"note": "E4", "start_beat": 5.0, "duration_beats": 2.0},
            {"note": "A4", "start_beat": 7.0, "duration_beats": 4.0},
          ],
        },
      ],
    },
    {
      "category_id": "jazz_standard",
      "style_label": "Jazz Standard",
      "description": "Swing and jazz phrasing drills with syncopation and smooth intervals.",
      "drills": [
        {
          "drill_id": "jazz_swing_phrasing_1",
          "title": "Swing Eighth Note Phrasing",
          "style_category": "Jazz Standard",
          "difficulty": "intermediate",
          "duration_sec": 75,
          "tempo_bpm": 120,
          "vocal_range": {"low": "Bb3", "high": "F5"},
          "objective": "Develop swing feel by practicing uneven eighth note rhythms.",
          "performance_tips": [
            "Let the first eighth note linger slightly longer than the second",
            "Keep a relaxed jaw to support smooth legato transitions",
          ],
          "melody_reference": [
            {"note": "Bb3", "start_beat": 0.0, "duration_beats": 1.5},
            {"note": "D4", "start_beat": 1.5, "duration_beats": 1.0},
            {"note": "F4", "start_beat": 2.5, "duration_beats": 1.5},
            {"note": "A4", "start_beat": 4.0, "duration_beats": 1.0},
            {"note": "F5", "start_beat": 5.0, "duration_beats": 3.0},
          ],
        },
        {
          "drill_id": "jazz_scat_basics_1",
          "title": "Scat Syllable Basics",
          "style_category": "Jazz Standard",
          "difficulty": "advanced",
          "duration_sec": 90,
          "tempo_bpm": 140,
          "vocal_range": {"low": "C3", "high": "E5"},
          "objective": "Practice rhythmic scat patterns with clear syllable articulation.",
          "performance_tips": [
            "Use syllables like 'doo', 'bah', 'dee' for crisp attack",
            "Keep time steady even as melodic patterns vary",
            "Relax between phrases to avoid throat tension",
          ],
          "melody_reference": [
            {"note": "C4", "start_beat": 0.0, "duration_beats": 0.5},
            {"note": "E4", "start_beat": 0.5, "duration_beats": 0.5},
            {"note": "G4", "start_beat": 1.0, "duration_beats": 0.5},
            {"note": "Bb4", "start_beat": 1.5, "duration_beats": 1.0},
            {"note": "A4", "start_beat": 2.5, "duration_beats": 0.5},
            {"note": "F4", "start_beat": 3.0, "duration_beats": 1.0},
            {"note": "D4", "start_beat": 4.0, "duration_beats": 2.0},
          ],
        },
      ],
    },
    {
      "category_id": "rock_anthem",
      "style_label": "Rock Anthem",
      "description": "High-energy rock drills focusing on power, projection, and stamina.",
      "drills": [
        {
          "drill_id": "rock_power_projection_1",
          "title": "Power Chest Voice Projection",
          "style_category": "Rock Anthem",
          "difficulty": "intermediate",
          "duration_sec": 60,
          "tempo_bpm": 130,
          "vocal_range": {"low": "E3", "high": "B4"},
          "objective": "Build chest voice power and projection without straining.",
          "performance_tips": [
            "Engage core muscles for supported projection",
            "Avoid pushing from the throat; let resonance do the work",
          ],
          "melody_reference": [
            {"note": "E3", "start_beat": 0.0, "duration_beats": 1.0},
            {"note": "G3", "start_beat": 1.0, "duration_beats": 1.0},
            {"note": "B3", "start_beat": 2.0, "duration_beats": 1.0},
            {"note": "E4", "start_beat": 3.0, "duration_beats": 2.0},
            {"note": "B4", "start_beat": 5.0, "duration_beats": 3.0},
          ],
        },
        {
          "drill_id": "rock_belt_stamina_1",
          "title": "Belt Stamina Builder",
          "style_category": "Rock Anthem",
          "difficulty": "advanced",
          "duration_sec": 120,
          "tempo_bpm": 145,
          "vocal_range": {"low": "G3", "high": "D5"},
          "objective": "Develop vocal stamina for sustained belting passages.",
          "performance_tips": [
            "Pace your energy; start at 80% intensity and build",
            "Take quick catch breaths between phrases",
            "Keep larynx neutral to avoid vocal fatigue",
          ],
          "melody_reference": [
            {"note": "G3", "start_beat": 0.0, "duration_beats": 1.0},
            {"note": "B3", "start_beat": 1.0, "duration_beats": 1.0},
            {"note": "D4", "start_beat": 2.0, "duration_beats": 1.5},
            {"note": "G4", "start_beat": 3.5, "duration_beats": 2.0},
            {"note": "B4", "start_beat": 5.5, "duration_beats": 1.5},
            {"note": "D5", "start_beat": 7.0, "duration_beats": 3.0},
          ],
        },
        {
          "drill_id": "rock_grit_intro_1",
          "title": "Controlled Grit Introduction",
          "style_category": "Rock Anthem",
          "difficulty": "beginner",
          "duration_sec": 45,
          "tempo_bpm": 100,
          "vocal_range": {"low": "A3", "high": "E4"},
          "objective": "Safely introduce vocal grit texture at low intensity.",
          "performance_tips": [
            "Use minimal air pressure; grit comes from fold closure, not force",
            "Stop immediately if you feel pain or excessive strain",
          ],
          "melody_reference": [
            {"note": "A3", "start_beat": 0.0, "duration_beats": 2.0},
            {"note": "C4", "start_beat": 2.0, "duration_beats": 2.0},
            {"note": "E4", "start_beat": 4.0, "duration_beats": 4.0},
          ],
        },
      ],
    },
  ],
}


def get_catalog() -> dict[str, Any]:
  """Return a deep copy of the full karaoke drill catalog."""
  return deepcopy(_KARAOKE_CATALOG)


def get_drill_by_id(drill_id: str) -> dict[str, Any] | None:
  """Return a deep copy of a single drill by its ID, or None if not found."""
  for cat in _KARAOKE_CATALOG["categories"]:
    for drill in cat["drills"]:
      if drill["drill_id"] == drill_id:
        return deepcopy(drill)
  return None
