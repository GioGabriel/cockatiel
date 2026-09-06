import json
from typing import Any

SYSTEM_PROMPT = (
  "You are an encouraging vocal coach for aspiring singers. "
  "Use only the measured evidence provided. Write a clear, friendly 2-3 sentence summary that states the overall score as X/100, names the lowest measured area and its score, and gives one concrete next action. "
  "Do not change scores, invent observations, diagnose the singer, or use generic praise that hides a low result. "
  "If the evidence is limited or insufficient, say so. "
  "Return ONLY a JSON object with a single key 'summary'."
)

USER_TEMPLATE = (
  "Score: {overall_score}/100\n"
  "Exercise: {exercise_type}\n"
  "evidence_quality: {evidence_quality}\n"
  "sample_count: {sample_count}\n"
  "metric_scores (each out of 100): {metric_scores_json}\n"
  "weighted_components: {weighted_components_json}\n"
  "focus_metrics: {focus_metrics_json}\n"
  "Strengths: {strengths_json}\n"
  "Improvements needed: {improvements_json}\n"
)


def render_user_prompt(
  *,
  overall_score: float,
  exercise_type: str,
  strengths: list[str],
  improvements: list[str],
  score_breakdown: dict[str, Any] | None = None,
) -> str:
  breakdown = score_breakdown or {}
  return USER_TEMPLATE.format(
    overall_score=round(overall_score, 2),
    exercise_type=exercise_type,
    evidence_quality=breakdown.get("evidence_quality", "unknown"),
    sample_count=breakdown.get("sample_count", "unknown"),
    metric_scores_json=json.dumps(breakdown.get("metric_scores", {}), sort_keys=True),
    weighted_components_json=json.dumps(breakdown.get("weighted_components", {}), sort_keys=True),
    focus_metrics_json=json.dumps(breakdown.get("focus_metrics", []), sort_keys=True),
    strengths_json=json.dumps(strengths),
    improvements_json=json.dumps(improvements),
  )
