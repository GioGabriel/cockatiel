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
  total_duration_sec = float(drill.get("duration_sec") or 60.0)
  
  stages = []
  melody = drill.get("melody_reference") or []
  if not melody:
    melody = [{"note": "C4", "start_beat": 0.0, "duration_beats": 4.0}]
    
  # Calculate length of one melody loop in beats (adding a 2-beat breathing rest between repetitions)
  max_beat_in_melody = max((float(n.get("start_beat") or 0.0) + float(n.get("duration_beats") or 1.0)) for n in melody)
  loop_stride_beats = max_beat_in_melody + 2.0
  loop_stride_sec = loop_stride_beats * sec_per_beat

  stage_idx = 1
  current_loop_offset_sec = 0.0
  while current_loop_offset_sec < total_duration_sec:
    for note in melody:
      start_sec = current_loop_offset_sec + float(note.get("start_beat") or 0.0) * sec_per_beat
      duration_sec = float(note.get("duration_beats") or 1.0) * sec_per_beat
      end_sec = start_sec + duration_sec
      
      if start_sec >= total_duration_sec:
        break
      if end_sec > total_duration_sec:
        end_sec = total_duration_sec
        duration_sec = end_sec - start_sec
        if duration_sec <= 0.1:
          break
          
      target_label = str(note.get("note") or "C4")
      stages.append({
        "stage_id": f"stage_{stage_idx}",
        "title": target_label,
        "target_label": target_label,
        "solfege": target_label,
        "instruction": f"Sing {target_label} • Match the pitch line!",
        "duration_sec": round(duration_sec, 3),
        "start_sec": round(start_sec, 3),
        "end_sec": round(end_sec, 3),
      })
      stage_idx += 1
    current_loop_offset_sec += loop_stride_sec
    
  runtime_plan = {
    "pattern_id": drill_id,
    "pattern_type": "karaoke",
    "summary": drill.get("objective") or "",
    "difficulty": drill.get("difficulty") or "beginner",
    "key": "C",
    "octave": 4,
    "total_duration_sec": round(total_duration_sec, 3),
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


def get_karaoke_progress(user_id: str) -> dict[str, Any]:
  from time import time
  from app.repositories.provider import get_session_repository
  repository = get_session_repository()
  sessions = repository.list_by_user(user_id)

  aggregate: dict[str, dict[str, Any]] = {}
  for session in sessions:
    if session.get("mode") != "karaoke":
      continue
    if session.get("status") != "completed":
      continue

    exercise_id = str(session.get("exercise_id") or session.get("exercise_type") or "").strip().lower()
    if not exercise_id:
      continue

    score = float(session.get("overall_score") or 0)
    completed_at = int(session.get("completed_at") or session.get("created_at") or 0)
    item = aggregate.setdefault(
      exercise_id,
      {
        "exercise_id": exercise_id,
        "sessions_completed": 0,
        "total_score": 0.0,
        "best_score": 0.0,
        "last_score": 0.0,
        "last_completed_at": 0,
      },
    )
    # Each attempt in a completed session is typically a "take" 
    # But wait, sessions_completed maps to total completed sessions.
    item["sessions_completed"] += 1
    item["total_score"] += score
    item["best_score"] = max(float(item["best_score"]), score)
    if completed_at >= int(item["last_completed_at"]):
      item["last_score"] = score
      item["last_completed_at"] = completed_at

  progress_items: list[dict[str, Any]] = []
  for exercise_id, item in aggregate.items():
    sessions_completed = int(item["sessions_completed"])
    avg_score = round(float(item["total_score"]) / max(sessions_completed, 1), 2)
    drill = get_drill_by_id(exercise_id)
    progress_items.append(
      {
        "exercise_id": exercise_id,
        "exercise_name": str((drill or {}).get("title") or exercise_id),
        "category_id": str((drill or {}).get("style_category") or "karaoke"),
        "sessions_completed": sessions_completed,
        "avg_score": avg_score,
        "best_score": round(float(item["best_score"]), 2),
        "last_score": round(float(item["last_score"]), 2),
        "last_completed_at": int(item["last_completed_at"]),
      }
    )

  progress_items.sort(key=lambda item: item["last_completed_at"], reverse=True)

  return {
    "user_id": user_id,
    "generated_at": int(time() * 1000),
    "items": progress_items,
  }

