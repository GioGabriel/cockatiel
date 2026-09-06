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

_TARGET_COMPARISON_METRICS = {
  "pitch_accuracy",
  "timing_accuracy",
  "pitch_stability",
  "vibrato_consistency",
  "note_transition_smoothness",
}

_METRIC_DETAIL_ACTIONS = {
  "pitch_accuracy": "Match one target note at a time with the guide, then repeat the phrase slowly.",
  "timing_accuracy": "Wait for the target window, count the beat, and repeat the same phrase without rushing.",
  "breath_control": "Take a relaxed breath before the phrase and keep the airflow steady until it ends.",
  "pitch_stability": "Hold a comfortable note for a few seconds and keep the sound even instead of pushing for volume.",
  "vibrato_consistency": "Make the sustained note steady first, then add a gentle, natural vibrato.",
  "note_transition_smoothness": "Slow the two-note change down and connect the next target without sliding past it.",
  "phase_completion_rate": "Follow every inhale, hold, and exhale to the final count before starting the next phase.",
  "pace_adherence": "Let the guide set the speed and keep each inhale or exhale relaxed rather than rushed.",
  "cycle_consistency": "Repeat the same breathing pattern at a comfortable pace so each cycle feels similar.",
  "completion_rate": "Use a shorter routine first, then complete the full sequence one calm phase at a time.",
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


def _metric_detail_for(
  score_breakdown: dict[str, Any],
  metric: str,
  score: float,
) -> dict[str, Any]:
  details = score_breakdown.get("metric_details") or {}
  detail = details.get(metric)
  if isinstance(detail, dict):
    return detail
  return {
    "status": "measured",
    "reason": f"The deterministic scorer measured this area at {score:.0f}/100.",
    "observed_frames": 0,
    "coverage_pct": 0,
  }


class CoachingLogicEngine:
  @staticmethod
  def build_detailed_improvements(
    *,
    exercise_type: str,
    metric_summary: dict[str, Any],
    score_breakdown: dict[str, Any],
  ) -> list[dict[str, str]]:
    """Build a useful fallback plan from evidence, not generic encouragement."""
    is_breathing = metric_summary.get("metric_mode") == "breathing"
    guidance = _BREATHING_GUIDANCE if is_breathing else _VOICE_GUIDANCE
    metric_scores = score_breakdown.get("metric_scores") or {}
    metric_details = score_breakdown.get("metric_details") or {}
    metric_keys = [field for field in guidance if field in metric_scores]
    metric_keys.extend(
      field for field in metric_scores
      if field not in metric_keys and field in metric_details
    )

    def priority(field: str) -> tuple[int, float]:
      detail = _metric_detail_for(score_breakdown, field, _safe_score(metric_scores.get(field)))
      status = str(detail.get("status") or "measured")
      if status == "not_measurable":
        return (0, 0.0)
      if status == "not_applicable":
        return (3, 100.0)
      return (1, _safe_score(metric_scores.get(field)))

    ordered = sorted(metric_keys, key=priority)
    improvements: list[dict[str, str]] = []
    for field in ordered:
      if len(improvements) >= 3:
        break
      score = _safe_score(metric_scores.get(field))
      detail = _metric_detail_for(score_breakdown, field, score)
      status = str(detail.get("status") or "measured")
      if status == "not_applicable":
        continue
      reason = str(detail.get("reason") or "The scorer did not provide a detailed reason.")
      label = _METRIC_LABELS.get(field, field.replace("_", " "))
      metric_guidance = guidance.get(field, {})

      if status == "not_measurable":
        finding = f"{label.title()} was not measurable in this take."
        action = (
          "Make sure the guided target is visible and active, then sing after it starts."
          if field in _TARGET_COMPARISON_METRICS
          else "Check microphone access and record a complete guided cycle."
        )
        practice_plan = "Repeat one short guided target and confirm that the live target indicator is moving before judging the result."
        why_it_matters = "A missing comparison signal cannot tell you whether the singing was accurate, so it should not be treated as a skill failure."
        priority_label = "high"
      else:
        if score < 60:
          priority_label = "high"
        elif score < 80:
          priority_label = "medium"
        else:
          priority_label = "low"
        finding = metric_guidance.get("needs_work") or metric_guidance.get("developing") or f"{label.title()} can be refined."
        action = _METRIC_DETAIL_ACTIONS.get(field, "Repeat the exercise slowly and focus on this measured area.")
        practice_plan = metric_guidance.get("exercise") or action
        why_it_matters = f"This area contributed {score:.0f}/100 to the measured take and is a useful next target for practice."

      improvements.append({
        "metric_key": field,
        "priority": priority_label,
        "finding": finding,
        "evidence": reason,
        "why_it_matters": why_it_matters,
        "action": action,
        "practice_plan": practice_plan,
      })

    if not improvements:
      improvements.append({
        "metric_key": "overall_score",
        "priority": "medium",
        "finding": "The take produced a baseline but no metric-specific improvement was available.",
        "evidence": "The saved score did not include a detailed metric report.",
        "why_it_matters": "A longer, guided recording will make the next review more specific.",
        "action": "Record the exercise again with the microphone and target guide active.",
        "practice_plan": "Use one short phrase and wait for the live target before singing.",
      })
    return improvements

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
    score_breakdown: dict[str, Any] | None = None,
  ) -> str:
    score_int = int(round(_safe_score(overall_score)))
    mode_label = "Karaoke song performance" if "karaoke" in exercise_type.lower() else "Vocal Coach training session"

    if _sample_count(metric_summary) <= 0:
      return "We could not capture enough practice data for a reliable score. Check your microphone and try a short take."

    parts = [f"Your practice score was {score_int}/100 for this {mode_label}."]
    weakest_metric = CoachingLogicEngine._weakest_metric(metric_summary)
    if score_breakdown:
      detailed = score_breakdown.get("metric_details") or {}
      not_measurable = [
        detail for detail in detailed.values()
        if isinstance(detail, dict) and detail.get("status") == "not_measurable"
      ]
      if not_measurable:
        reason = str(not_measurable[0].get("reason") or "Some metrics were not measurable in this take.")
        parts.append(reason)
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
