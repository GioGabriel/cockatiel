from typing import Any

from app.modules.training.catalog import default_metric_weights, get_exercise

VOICE_METRIC_FIELDS = (
  "pitch_accuracy",
  "timing_accuracy",
  "breath_control",
  "pitch_stability",
  "vibrato_consistency",
  "note_transition_smoothness",
)

BREATHING_METRIC_FIELDS = (
  "phase_completion_rate",
  "pace_adherence",
  "cycle_consistency",
  "completion_rate",
)


def metric_mode_for_exercise(exercise_id: str) -> str:
  exercise = get_exercise(exercise_id) or {}
  exercise_mode = str(exercise.get("exercise_mode") or "voice").strip().lower()
  return "breathing" if exercise_mode == "breathing_timer" else "voice"


def metric_fields_for_exercise(exercise_id: str) -> tuple[str, ...]:
  return BREATHING_METRIC_FIELDS if metric_mode_for_exercise(exercise_id) == "breathing" else VOICE_METRIC_FIELDS


def _default_breathing_metric_weights() -> dict[str, float]:
  return {
    "phase_completion_rate": 0.35,
    "pace_adherence": 0.3,
    "cycle_consistency": 0.2,
    "completion_rate": 0.15,
  }


def _normalized_metric_weights(exercise_id: str, metric_fields: tuple[str, ...]) -> dict[str, float]:
  exercise = get_exercise(exercise_id) or {}
  weights = dict(exercise.get("metric_weights") or default_metric_weights())
  total = sum(float(weights.get(field, 0.0)) for field in metric_fields)
  if total <= 0:
    fallback = (
      _default_breathing_metric_weights()
      if metric_mode_for_exercise(exercise_id) == "breathing"
      else default_metric_weights()
    )
    total = sum(float(fallback[field]) for field in metric_fields)
    weights = fallback
  return {
    field: round(float(weights.get(field, 0.0)) / total, 4)
    for field in metric_fields
  }


def _metric_value(metric_summary: dict[str, float | int], field: str) -> float:
  return round(float(metric_summary.get(field, 0.0)), 2)


def score_training_attempt(
  *,
  exercise_id: str,
  metric_summary: dict[str, float | int],
) -> dict[str, Any]:
  exercise = get_exercise(exercise_id) or {}
  metric_mode = metric_mode_for_exercise(exercise_id)
  metric_fields = metric_fields_for_exercise(exercise_id)
  weights = _normalized_metric_weights(exercise_id, metric_fields)
  metric_scores = {
    field: _metric_value(metric_summary, field)
    for field in metric_fields
  }
  weighted_components = {
    field: round(metric_scores[field] * weights[field], 2)
    for field in metric_fields
  }
  overall_score = round(sum(weighted_components.values()), 2)

  default_focus_metrics = list(metric_fields[:3])
  focus_metrics = list(exercise.get("focus_metrics") or default_focus_metrics)
  ranked_focus_metrics = sorted(
    focus_metrics,
    key=lambda field: metric_scores.get(field, 0.0),
  )
  weakest_metric = ranked_focus_metrics[0] if ranked_focus_metrics else metric_fields[0]
  strongest_metric = ranked_focus_metrics[-1] if ranked_focus_metrics else metric_fields[0]

  thresholds = dict(exercise.get("success_thresholds") or {})
  overall_threshold = float(thresholds.get("overall_score") or 0.0)
  metric_floors = {
    field: float(value)
    for field, value in dict(thresholds.get("metric_floors") or {}).items()
  }
  passed_threshold = overall_score >= overall_threshold and all(
    metric_scores.get(field, 0.0) >= value
    for field, value in metric_floors.items()
  )

  return {
    "overall_score": overall_score,
    "score_breakdown": {
      "metric_mode": metric_mode,
      "focus_metrics": focus_metrics,
      "metric_scores": metric_scores,
      "weighted_components": weighted_components,
    },
    "strongest_metric": strongest_metric,
    "weakest_metric": weakest_metric,
    "passed_threshold": passed_threshold,
  }
