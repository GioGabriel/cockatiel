from time import time
from typing import Any

from app.core.exceptions import ApiError
from app.modules.training.catalog import (
  default_attempt_policy,
  get_catalog,
  get_exercise,
  resolve_duration_sec,
)
from app.modules.training.targets import canonical_training_target
from app.repositories.provider import get_session_repository

_VALID_DIFFICULTIES = {"beginner", "intermediate", "advanced"}
_VALID_KEYS = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
_VALID_PACES = {"standard", "slow"}
_VALID_PHRASE_MODES = {"full", "short"}


def get_training_catalog() -> dict[str, Any]:
  return get_catalog()


def get_training_validation(exercise_id: str) -> dict[str, Any]:
  exercise = get_exercise(exercise_id)
  if not exercise:
    raise ApiError(
      code="TRAINING_EXERCISE_NOT_FOUND",
      message="Training exercise is not defined in catalog.",
      status_code=400,
    )
  return exercise


def _normalize_difficulty(raw_value: Any, default_value: str) -> str:
  difficulty = str(raw_value or default_value or "beginner").lower()
  return difficulty if difficulty in _VALID_DIFFICULTIES else "beginner"


def _normalize_key(raw_value: Any) -> str:
  normalized = str(raw_value or "C").upper().strip()
  return normalized if normalized in _VALID_KEYS else "C"


def _normalize_octave(raw_value: Any) -> int:
  try:
    octave = int(raw_value or 4)
  except (TypeError, ValueError):
    octave = 4
  return max(2, min(octave, 6))


def _normalize_pace(raw_value: Any) -> str:
  pace = str(raw_value or "standard").lower().strip()
  return pace if pace in _VALID_PACES else "standard"


def _normalize_phrase_mode(raw_value: Any, *, difficulty: str, is_voice_pattern: bool) -> str:
  phrase_mode = str(raw_value or "full").lower().strip()
  if phrase_mode not in _VALID_PHRASE_MODES:
    return "full"
  # Short phrases are deliberately a beginner voice affordance. Breathing timers
  # and higher-level patterns retain their authored progression.
  if phrase_mode == "short" and (difficulty != "beginner" or not is_voice_pattern):
    return "full"
  return phrase_mode


def _shorten_beginner_pattern(pattern: dict[str, Any], *, phrase_mode: str) -> dict[str, Any]:
  if phrase_mode != "short":
    return pattern

  stages = list(pattern.get("stages") or [])
  if not stages:
    return pattern

  shortened = dict(pattern)
  selected_stages = stages[:3]
  labels = [
    str(stage.get("target_label") or stage.get("solfege") or stage.get("title") or "Target")
    for stage in selected_stages
  ]
  if len(stages) > 3:
    shortened["pattern_id"] = f"{pattern.get('pattern_id') or 'pattern'}_short"
  shortened["summary"] = (
    "Short three-note phrase for a comfortable repeat: "
    f"{', '.join(labels)}."
  )
  shortened["teaching_note"] = (
    "Short phrase mode uses the first guided targets so you can reset your breath "
    "between repetitions before returning to the full beginner foundation."
  )
  shortened["stages"] = selected_stages
  return shortened


def _build_exercise_spec(exercise: dict[str, Any]) -> dict[str, Any]:
  return {
    "exercise_id": exercise["exercise_id"],
    "name": exercise["name"],
    "description": exercise["description"],
    "objective": exercise.get("objective") or exercise.get("description") or "Improve your vocal skills.",
    "what_you_do": exercise.get("what_you_do") or exercise.get("description") or "Follow the guided instructions during the session.",
    "requires_microphone": bool(exercise.get("requires_microphone", True)),
    "exercise_mode": str(exercise.get("exercise_mode") or "voice"),
    "instructions": list(exercise.get("instructions") or []),
    "ai_focus": exercise.get("ai_focus") or "Technique consistency",
    "training_basis": list(exercise.get("training_basis") or []),
    "measurement_plan": list(exercise.get("measurement_plan") or []),
    "measurement_limits": list(exercise.get("measurement_limits") or []),
    "default_difficulty": exercise.get("default_difficulty") or "beginner",
    "recommended_order": int(exercise.get("recommended_order") or 1),
    "focus_metrics": list(exercise.get("focus_metrics") or []),
    "metric_weights": dict(exercise.get("metric_weights") or {}),
    "success_thresholds": dict(exercise.get("success_thresholds") or {}),
    "coach_cues": dict(exercise.get("coach_cues") or {}),
  }


def _resolve_pattern(exercise: dict[str, Any], difficulty: str, requested_pattern: str | None) -> dict[str, Any]:
  patterns_by_difficulty = dict(exercise.get("patterns_by_difficulty") or {})
  default_pattern = dict(
    patterns_by_difficulty.get(difficulty)
    or patterns_by_difficulty.get(exercise.get("default_difficulty") or "beginner")
    or next(iter(patterns_by_difficulty.values()), {})
  )

  normalized_requested = str(requested_pattern or "default").strip().lower()
  if normalized_requested in {"", "default"}:
    return default_pattern

  for candidate in patterns_by_difficulty.values():
    pattern_id = str(candidate.get("pattern_id") or "").strip().lower()
    if pattern_id == normalized_requested:
      return dict(candidate)

  return default_pattern


def resolve_training_runtime(
  *,
  exercise_id: str,
  difficulty: str,
  key: str,
  octave: int,
  duration_sec: int,
  requested_pattern: str | None = None,
  pace: str = "standard",
  phrase_mode: str = "full",
) -> dict[str, Any]:
  exercise = get_training_validation(exercise_id)
  is_voice_pattern = str(exercise.get("exercise_mode") or "voice") == "voice"
  normalized_pace = _normalize_pace(pace)
  normalized_phrase_mode = _normalize_phrase_mode(
    phrase_mode,
    difficulty=difficulty,
    is_voice_pattern=is_voice_pattern,
  )
  pattern = _shorten_beginner_pattern(
    _resolve_pattern(exercise, difficulty, requested_pattern),
    phrase_mode=normalized_phrase_mode,
  )
  raw_stages = list(pattern.get("stages") or [])

  pattern_type = str(pattern.get("pattern_type") or "default")
  default_rest_beats = 0.5 if difficulty == "beginner" else 0.25
  stage_units: list[tuple[int, float]] = []
  for index, stage in enumerate(raw_stages):
    beats = max(int(stage.get("beats") or 1), 1)
    if not is_voice_pattern or index == len(raw_stages) - 1:
      rest_beats = 0.0
    else:
      try:
        rest_beats = max(float(stage.get("rest_after_beats", default_rest_beats)), 0.0)
      except (TypeError, ValueError):
        rest_beats = default_rest_beats
    stage_units.append((beats, rest_beats))

  total_units = max(sum(beats + rest for beats, rest in stage_units), 1.0)
  seconds_per_unit = duration_sec / total_units
  cursor_sec = 0.0
  stages: list[dict[str, Any]] = []
  for index, stage in enumerate(raw_stages):
    beats, rest_beats = stage_units[index]
    start_sec = round(cursor_sec, 2)
    is_last_stage = index == len(raw_stages) - 1
    if is_last_stage:
      stage_duration_sec = max(round(duration_sec - start_sec, 2), 0.1)
      rest_after_sec = 0.0
    else:
      stage_duration_sec = max(round(beats * seconds_per_unit, 2), 0.1)
      rest_after_sec = round(rest_beats * seconds_per_unit, 2)
    end_sec = round(start_sec + stage_duration_sec, 2)
    rest_end_sec = round(min(end_sec + rest_after_sec, duration_sec), 2)
    target_label = str(stage.get("target_label") or stage.get("solfege") or "Target")
    target_type = str(
      stage.get("target_type")
      or (
        "breathing_phase"
        if not is_voice_pattern
        else "transition"
        if index > 0 and pattern_type in {"transition", "jump"}
        else "sustained_note"
      )
    )
    breath_cue = bool(stage.get("breath_cue", is_voice_pattern and rest_after_sec >= 0.5))
    target = canonical_training_target(
      target_id=str(stage.get("stage_id") or f"stage_{index + 1}"),
      solfege=target_label,
      key=key,
      octave=octave,
      start_sec=start_sec,
      end_sec=end_sec,
      rest_after_sec=rest_after_sec,
      target_type=target_type,
      breath_cue=breath_cue,
    )
    stages.append(
      {
        "stage_id": str(stage.get("stage_id") or f"stage_{index + 1}"),
        "title": str(stage.get("title") or target_label or f"Stage {index + 1}"),
        "target_label": target_label,
        "solfege": target_label,
        "instruction": str(stage.get("instruction") or "Stay supported and steady."),
        "duration_sec": stage_duration_sec,
        "start_sec": start_sec,
        "end_sec": end_sec,
        "rest_after_sec": rest_after_sec,
        "rest_end_sec": rest_end_sec,
        "target_type": target_type,
        "breath_cue": breath_cue,
        "target_frequency_hz": target["target_frequency_hz"],
        "scale_degree": target["scale_degree"],
        "midi_note": target["midi_note"],
        "target": target,
      }
    )
    cursor_sec = rest_end_sec

  return {
    "pattern_id": str(pattern.get("pattern_id") or f"{exercise_id}_{difficulty}"),
    "pattern_type": pattern_type,
    "summary": str(pattern.get("summary") or exercise.get("description") or ""),
    "teaching_note": str(pattern.get("teaching_note") or "Follow the guided steps and use the live cue as your next action."),
    "difficulty": difficulty,
    "key": key,
    "octave": octave,
    "total_duration_sec": duration_sec,
    "pace": normalized_pace,
    "phrase_mode": normalized_phrase_mode,
    "pacing_model": "guided_note_windows_with_phrase_rests" if is_voice_pattern else "guided_phase_windows",
    "pacing_basis": (
      "Stage beats allocate note windows; explicit rests create comfortable phrase breaks. "
      f"The {'slower' if normalized_pace == 'slow' else 'standard'} pace is a product pacing choice. "
      "Timing is measured against target-window entry and coverage, not a musical beat grid."
      if is_voice_pattern
      else "Stage beats allocate guided breathing phases; the timer measures phase completion and pacing only."
    ),
    "stages": stages,
  }


def build_training_session_metadata(
  *,
  exercise_id: str,
  training_config: dict[str, Any] | None,
) -> dict[str, Any]:
  exercise = get_training_validation(exercise_id)

  config = dict(training_config or {})
  difficulty = _normalize_difficulty(config.get("difficulty"), str(exercise.get("default_difficulty") or "beginner"))
  key = _normalize_key(config.get("key"))
  octave = _normalize_octave(config.get("octave"))
  is_voice_pattern = str(exercise.get("exercise_mode") or "voice") == "voice"
  pace = _normalize_pace(config.get("pace"))
  phrase_mode = _normalize_phrase_mode(
    config.get("phrase_mode"),
    difficulty=difficulty,
    is_voice_pattern=is_voice_pattern,
  )

  attempt_policy = default_attempt_policy()
  requested_attempts = config.get("max_attempts")
  if isinstance(requested_attempts, int):
    attempt_policy["max_attempts"] = max(1, min(requested_attempts, 10))

  duration_sec = resolve_duration_sec(difficulty)
  if pace == "slow" and not isinstance(config.get("duration_sec"), int):
    duration_sec = round(duration_sec * 1.25)
  if isinstance(config.get("duration_sec"), int):
    duration_sec = max(10, min(int(config["duration_sec"]), 300))

  runtime_plan = resolve_training_runtime(
    exercise_id=exercise_id,
    difficulty=difficulty,
    key=key,
    octave=octave,
    duration_sec=duration_sec,
    requested_pattern=str(config.get("target_pattern") or "default"),
    pace=pace,
    phrase_mode=phrase_mode,
  )

  return {
    "category_id": exercise["category_id"],
    "exercise_id": exercise["exercise_id"],
    "exercise_spec": _build_exercise_spec(exercise),
    "training_config": {
      "difficulty": difficulty,
      "key": key,
      "octave": octave,
      "target_pattern": str(runtime_plan["pattern_id"]),
      "pace": pace,
      "phrase_mode": phrase_mode,
      "duration_sec": duration_sec,
      "max_attempts": int(attempt_policy["max_attempts"]),
    },
    "runtime_plan": runtime_plan,
    "attempt_policy": attempt_policy,
  }


def build_ai_feedback_context(session: dict[str, Any]) -> dict[str, Any]:
  attempts = [item for item in list(session.get("attempts") or []) if isinstance(item, dict)]
  selected_best_attempt_id = str(session.get("selected_best_attempt_id") or "")
  best_attempt = next(
    (item for item in attempts if str(item.get("attempt_id") or "") == selected_best_attempt_id),
    attempts[-1] if attempts else None,
  )

  exercise_spec = dict(session.get("exercise_spec") or {})
  training_config = dict(session.get("training_config") or {})
  return {
    "category_id": session.get("category_id"),
    "exercise_id": session.get("exercise_id") or session.get("exercise_type"),
    "exercise_name": exercise_spec.get("name") or session.get("exercise_type"),
    "objective": exercise_spec.get("objective"),
    "what_you_do": exercise_spec.get("what_you_do"),
    "exercise_mode": exercise_spec.get("exercise_mode"),
    "requires_microphone": exercise_spec.get("requires_microphone"),
    "training_basis": list(exercise_spec.get("training_basis") or []),
    "measurement_plan": list(exercise_spec.get("measurement_plan") or []),
    "measurement_limits": list(exercise_spec.get("measurement_limits") or []),
    "focus_metrics": list(exercise_spec.get("focus_metrics") or []),
    "difficulty": training_config.get("difficulty"),
    "key": training_config.get("key"),
    "octave": training_config.get("octave"),
    "target_pattern": training_config.get("target_pattern"),
    "pace": training_config.get("pace"),
    "phrase_mode": training_config.get("phrase_mode"),
    "runtime_pattern": dict(session.get("runtime_plan") or {}),
    "selected_best_attempt": {
      "attempt_index": best_attempt.get("attempt_index"),
      "score": best_attempt.get("score"),
      "score_breakdown": best_attempt.get("score_breakdown"),
      "strongest_metric": best_attempt.get("strongest_metric"),
      "weakest_metric": best_attempt.get("weakest_metric"),
      "passed_threshold": best_attempt.get("passed_threshold"),
    }
    if isinstance(best_attempt, dict)
    else None,
  }


def get_training_progress(user_id: str) -> dict[str, Any]:
  repository = get_session_repository()
  sessions = repository.list_by_user(user_id)

  aggregate: dict[str, dict[str, Any]] = {}
  for session in sessions:
    if session.get("mode") != "training":
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
    exercise = get_exercise(exercise_id)
    progress_items.append(
      {
        "exercise_id": exercise_id,
        "exercise_name": str((exercise or {}).get("name") or exercise_id),
        "category_id": str((exercise or {}).get("category_id") or "vocal_training"),
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


_GOAL_METRIC_MAP: dict[str, str | None] = {
  "pitch_improvement": "pitch_accuracy",
  "breath_control": "breath_control",
  "tone_quality": "pitch_stability",
  "range_extension": "note_transition_smoothness",
  "general_skill_building": None,
}


def get_training_recommendations(
  user_id: str,
  preferred_categories: list[str] | None = None,
  vocal_range: str | None = None,
  training_goal: str | None = None,
) -> dict[str, Any]:
  progress = get_training_progress(user_id)
  progress_by_exercise = {item["exercise_id"]: item for item in progress["items"]}

  catalog_categories = get_catalog()["categories"]

  if preferred_categories:
    catalog_categories = [
      cat for cat in catalog_categories
      if cat["category_id"] in preferred_categories
    ]

  goal_metric = _GOAL_METRIC_MAP.get(training_goal or "") if training_goal else None

  recommendations: list[dict[str, Any]] = []
  for category in catalog_categories:
    for exercise in category["exercises"]:
      exercise_id = exercise["exercise_id"]
      progress_item = progress_by_exercise.get(exercise_id)
      recommended_order = int(exercise.get("recommended_order") or 1)
      if not progress_item:
        reason = f"Recommended next to build your {exercise['name'].lower()} foundation."
        priority = 110.0 - (recommended_order * 3)
      else:
        avg_score = float(progress_item["avg_score"])
        weakest_focus = next(iter(exercise.get("focus_metrics") or []), "technique")
        reason = f"Revisit this drill to strengthen {weakest_focus.replace('_', ' ')}."
        priority = max(0.0, 100.0 - avg_score) + max(0.0, 10.0 - recommended_order)

      if goal_metric and goal_metric in list(exercise.get("focus_metrics") or []):
        priority += 5

      recommendations.append(
        {
          "exercise_id": exercise_id,
          "exercise_name": exercise["name"],
          "category_id": category["category_id"],
          "reason": reason,
          "priority": round(priority, 2),
        }
      )

  recommendations.sort(key=lambda item: item["priority"], reverse=True)

  return {
    "user_id": user_id,
    "generated_at": int(time() * 1000),
    "items": recommendations[:3],
  }
