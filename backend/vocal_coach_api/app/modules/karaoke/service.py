from typing import Any

from app.modules.karaoke.catalog import get_catalog, get_drill_by_id as _get_drill_by_id


def get_karaoke_catalog() -> dict[str, Any]:
  """Return the full karaoke drill catalog."""
  return get_catalog()


def get_drill_by_id(drill_id: str) -> dict[str, Any] | None:
  """Return a single drill by ID, or None if not found."""
  return _get_drill_by_id(drill_id)


def get_catalog_preview() -> dict[str, Any]:
  """Return a lightweight preview of the catalog without full drill details."""
  catalog = get_catalog()
  categories_preview = []
  total_drills = 0
  for cat in catalog["categories"]:
    drill_count = len(cat["drills"])
    total_drills += drill_count
    categories_preview.append({
      "category_id": cat["category_id"],
      "style_label": cat["style_label"],
      "drill_count": drill_count,
    })
  return {
    "module_id": catalog["module_id"],
    "title": catalog["title"],
    "description": catalog["description"],
    "category_count": len(catalog["categories"]),
    "total_drills": total_drills,
    "categories": categories_preview,
  }


def build_karaoke_session_metadata(drill_id: str) -> dict[str, Any]:
  """Build runtime plan and metadata for a karaoke session."""
  drill = get_drill_by_id(drill_id)
  if not drill:
    return {}
    
  tempo = float(drill.get("tempo_bpm") or 120)
  beats_per_sec = tempo / 60.0
  sec_per_beat = 1.0 / beats_per_sec
  
  stages = []
  melody = drill.get("melody_reference") or []
  for index, note in enumerate(melody):
    start_sec = float(note.get("start_beat") or 0.0) * sec_per_beat
    duration_sec = float(note.get("duration_beats") or 1.0) * sec_per_beat
    end_sec = start_sec + duration_sec
    target_label = str(note.get("note") or "C4")
    stages.append({
      "stage_id": f"stage_{index + 1}",
      "title": target_label,
      "target_label": target_label,
      "solfege": target_label,
      "instruction": f"Sing {target_label}",
      "duration_sec": max(1, int(round(duration_sec))),
      "start_sec": max(0, int(round(start_sec))),
      "end_sec": max(1, int(round(end_sec))),
    })
    
  runtime_plan = {
    "pattern_id": drill_id,
    "pattern_type": "karaoke",
    "summary": drill.get("objective") or "",
    "difficulty": drill.get("difficulty") or "beginner",
    "key": "C",
    "octave": 4,
    "total_duration_sec": int(drill.get("duration_sec") or 60),
    "stages": stages,
  }

  return {
    "category_id": drill.get("style_category") or "karaoke",
    "exercise_id": drill_id,
    "exercise_spec": drill,
    "training_config": {
      "difficulty": drill.get("difficulty") or "beginner",
      "duration_sec": drill.get("duration_sec") or 60,
      "max_attempts": 3,
    },
    "runtime_plan": runtime_plan,
  }
