import math
from typing import Any


_VOICE_GUIDANCE = {
  "pitch_accuracy": {
    "strong": "Pitch stayed close to the target notes",
    "developing": "Pitch is developing; keep matching the center of each target note",
    "needs_work": "Several notes drifted above or below the target",
    "exercise": "Slow note-matching drill with a steady reference tone",
  },
  "pitch_stability": {
    "strong": "Held notes stayed steady",
    "developing": "Held notes are becoming steadier; use a relaxed, even airflow",
    "needs_work": "Held notes wavered before they settled",
    "exercise": "Short, steady-note holds",
  },
  "timing_accuracy": {
    "strong": "Notes lined up closely with the beat",
    "developing": "Timing is developing; count the beat before each phrase",
    "needs_work": "Some phrases rushed or fell behind the beat",
    "exercise": "Beat-counting and metronome practice",
  },
  "breath_control": {
    "strong": "Breath support stayed steady through the phrases",
    "developing": "Breath support is developing; plan a relaxed breath before each phrase",
    "needs_work": "Air ran low before some phrases ended",
    "exercise": "Gentle 'sss' breath-pacing ladder",
  },
  "note_transition_smoothness": {
    "strong": "Transitions between notes were smooth",
    "developing": "Note changes are developing; connect each pitch without pushing",
    "needs_work": "Some note changes sounded abrupt or slid into place",
    "exercise": "Connected note-transition practice",
  },
  "vibrato_consistency": {
    "strong": "Vibrato sounded even and controlled",
    "developing": "Vibrato control is developing; keep the pulse gentle and unforced",
    "needs_work": "Vibrato was uneven or felt forced",
    "exercise": "Gentle vibrato-control drill",
  },
}

_BREATHING_GUIDANCE = {
  "phase_completion_rate": {
    "strong": "You completed each inhale, hold, and exhale phase",
    "developing": "Breathing phases are developing; follow the timer to the final count",
    "needs_work": "Some breathing phases ended too early",
    "exercise": "Beginner 4-4-4 breathing",
  },
  "pace_adherence": {
    "strong": "Your breathing pace matched the exercise",
    "developing": "Breathing pace is developing; let the timer set the speed",
    "needs_work": "Some inhales or exhales were too fast",
    "exercise": "Slow metronome breathing",
  },
  "cycle_consistency": {
    "strong": "Breath cycles stayed consistent",
    "developing": "Cycle consistency is developing; keep each repetition relaxed",
    "needs_work": "Breaths varied between shallow and deep",
    "exercise": "Repeatable breath-cycle practice",
  },
  "completion_rate": {
    "strong": "You completed nearly all of the guided routine",
    "developing": "Routine completion is developing; finish one calm cycle at a time",
    "needs_work": "The routine ended before all guided phases were complete",
    "exercise": "Short guided breathing repeat",
  },
}

_METRIC_LABELS = {
  "pitch_accuracy": "pitch accuracy",
  "timing_accuracy": "timing",
  "breath_control": "breath control",
  "pitch_stability": "note steadiness",
  "vibrato_consistency": "vibrato control",
  "note_transition_smoothness": "note transitions",
  "phase_completion_rate": "breathing phases",
  "pace_adherence": "breathing pace",
  "cycle_consistency": "cycle consistency",
  "completion_rate": "routine completion",
}


def _safe_score(value: Any) -> float:
  try:
    parsed = float(value)
  except (TypeError, ValueError):
    return 0.0
  if not math.isfinite(parsed):
    return 0.0
  return min(max(parsed, 0.0), 100.0)


def _sample_count(metrics: dict[str, Any]) -> int:
  try:
    return max(int(metrics.get("sample_count") or 0), 0)
  except (TypeError, ValueError):
    return 0


def _append_unique(items: list[str], value: str) -> None:
  if value not in items:
    items.append(value)


class CoachingLogicEngine:
  @staticmethod
  def evaluate(
    overall_score: float,
    exercise_type: str,
    metric_summary: dict[str, Any],
  ) -> tuple[list[str], list[str], list[str]]:
    strengths: list[str] = []
    improvements: list[str] = []
    next_exercises: list[str] = []

    is_breathing = metric_summary.get("metric_mode") == "breathing"
    has_data = (
      _sample_count(metric_summary) > 0
      or ("sample_count" not in metric_summary and any(
        field in metric_summary
        for field in (_BREATHING_GUIDANCE if is_breathing else _VOICE_GUIDANCE)
      ))
    )

    if not has_data:
      strengths.append("You started a practice attempt; the next take can give us clearer guidance.")
      improvements.append("We did not capture enough microphone data to score this take reliably.")
      next_exercises.append("Check microphone access, then try a short note-matching drill")
      return strengths, improvements, next_exercises

    if is_breathing:
      CoachingLogicEngine._evaluate_breathing(metric_summary, strengths, improvements, next_exercises)
    else:
      CoachingLogicEngine._evaluate_voice(metric_summary, strengths, improvements, next_exercises)

    score = _safe_score(overall_score)
    if not strengths:
      if score >= 85:
        strengths.append("Your overall control was consistent")
      elif score >= 70:
        strengths.append("You built a solid foundation during this attempt")
      else:
        strengths.append("You completed a practice attempt and now have a clear baseline")

    if not improvements:
      if score < 95:
        improvements.append("Keep refining small changes in control and expression")
      else:
        improvements.append("You are ready to add a more expressive challenge")

    if not next_exercises:
      if "karaoke" in exercise_type.lower():
        next_exercises.append("Repeat the song section with steadier phrasing")
      elif is_breathing:
        next_exercises.append("Repeat the same breath cycle with a calmer release")
      else:
        next_exercises.append("Vocal agility and note-connection drill")

    return strengths[:3], improvements[:3], next_exercises[:3]

  @staticmethod
  def generate_fallback_summary(
    overall_score: float,
    exercise_type: str,
    metric_summary: dict[str, Any],
    strengths: list[str],
    improvements: list[str],
  ) -> str:
    score_int = int(round(_safe_score(overall_score)))
    mode_label = "Karaoke song performance" if "karaoke" in exercise_type.lower() else "Vocal Coach training session"

    if _sample_count(metric_summary) <= 0:
      return "We could not capture enough practice data for a reliable score. Check your microphone and try a short take."

    parts = [f"Your practice score was {score_int}/100 for this {mode_label}."]
    weakest_metric = CoachingLogicEngine._weakest_metric(metric_summary)
    if weakest_metric is not None:
      weakest_field, weakest_score = weakest_metric
      parts.append(
        f"Your first focus area is {_METRIC_LABELS.get(weakest_field, weakest_field)} at "
        f"{int(round(weakest_score))}/100 in this take."
      )
    if improvements:
      parts.append(f"Next step: {improvements[0].rstrip('.')}.")
    parts.append("Short, regular practice will help these skills feel more natural.")
    return " ".join(parts)

  @staticmethod
  def _weakest_metric(metrics: dict[str, Any]) -> tuple[str, float] | None:
    guidance = _BREATHING_GUIDANCE if metrics.get("metric_mode") == "breathing" else _VOICE_GUIDANCE
    candidates: list[tuple[str, float]] = []
    for field in guidance:
      if field == "vibrato_consistency" and field not in metrics:
        continue
      if field in metrics:
        candidates.append((field, _safe_score(metrics.get(field))))
    return min(candidates, key=lambda item: item[1]) if candidates else None

  @staticmethod
  def _evaluate_voice(
    metrics: dict[str, Any],
    strengths: list[str],
    improvements: list[str],
    next_exercises: list[str],
  ) -> None:
    for field, guidance in _VOICE_GUIDANCE.items():
      value = _safe_score(metrics.get(field))
      # A zero vibrato value means no measurable vibrato was attempted, not a failed skill.
      if field == "vibrato_consistency" and field not in metrics:
        continue
      if value >= 85:
        _append_unique(strengths, guidance["strong"])
      elif value >= 70:
        _append_unique(improvements, guidance["developing"])
        if len(next_exercises) < 3:
          _append_unique(next_exercises, guidance["exercise"])
      else:
        _append_unique(improvements, guidance["needs_work"])
        _append_unique(next_exercises, guidance["exercise"])

  @staticmethod
  def _evaluate_breathing(
    metrics: dict[str, Any],
    strengths: list[str],
    improvements: list[str],
    next_exercises: list[str],
  ) -> None:
    try:
      interruption_count = max(int(metrics.get("interruption_count") or 0), 0)
    except (TypeError, ValueError):
      interruption_count = 0
    if interruption_count > 0:
      _append_unique(improvements, "The routine had interruptions; reset posture and continue from the next calm breath")
      _append_unique(next_exercises, "Focus and relaxation breathing repeat")

    for field, guidance in _BREATHING_GUIDANCE.items():
      value = _safe_score(metrics.get(field))
      if value >= 85:
        _append_unique(strengths, guidance["strong"])
      elif value >= 70:
        _append_unique(improvements, guidance["developing"])
        if len(next_exercises) < 3:
          _append_unique(next_exercises, guidance["exercise"])
      else:
        _append_unique(improvements, guidance["needs_work"])
        _append_unique(next_exercises, guidance["exercise"])

    if interruption_count == 0:
      _append_unique(strengths, "Breathing stayed uninterrupted during the guided cycle")
