import json
from typing import Any

SYSTEM_PROMPT = (
  "You are an encouraging vocal coach for aspiring singers. "
  "Use only the measured evidence provided. Write a clear, friendly 2-3 sentence summary. State an X/100 score only when score_status is measured or legacy; when it is not_scorable or insufficient_evidence, say that the result is inconclusive and explain the missing evidence instead. Name the lowest measurable area and its score only when one exists, then give one concrete next action. "
  "Return up to three detailed improvement plans. Each plan must name a metric_key from the supplied metric scores, quote the supplied evidence numbers or reason, include the segment label and time range when supplied, explain why the area matters, and give a specific action and short practice plan. Include evidence_quality and a limitation when the evidence is partial or missing. "
  "Use the exercise's training_basis to explain why the drill exists, and treat measurement_limits as hard boundaries. Never present a proxy as direct airflow, resonance, tension, or clinical measurement. "
  "Do not change scores, invent observations, diagnose the singer, or use generic praise that hides a low result. "
  "If a metric or segment is not_measurable, explain that the signal was missing and do not blame the singer for that zero. A zero from missing target data is not a failed singing result. "
  "Be direct and specific while remaining encouraging. "
  "Return ONLY a JSON object with exactly these keys: 'summary' and 'detailed_improvements'."
)

USER_TEMPLATE = (
  "Score: {overall_score}/100 (numeric compatibility value; presentation status is authoritative)\n"
  "Exercise: {exercise_type}\n"
  "evidence_quality: {evidence_quality}\n"
  "score_status: {score_status}\n"
  "legacy_evidence: {legacy_evidence}\n"
  "sample_count: {sample_count}\n"
  "metric_scores (each out of 100): {metric_scores_json}\n"
  "weighted_components: {weighted_components_json}\n"
  "focus_metrics: {focus_metrics_json}\n"
  "training_basis: {training_basis_json}\n"
  "measurement_plan: {measurement_plan_json}\n"
  "measurement_limits: {measurement_limits_json}\n"
  "recording_evidence: {recording_evidence_json}\n"
  "metric_details: {metric_details_json}\n"
  "segments: {segments_json}\n"
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
  exercise_context: dict[str, Any] | None = None,
) -> str:
  breakdown = score_breakdown or {}
  context = exercise_context or {}
  return USER_TEMPLATE.format(
    overall_score=round(overall_score, 2),
    exercise_type=exercise_type,
    evidence_quality=breakdown.get("evidence_quality", "unknown"),
    score_status=breakdown.get("score_status", "unknown"),
    legacy_evidence=breakdown.get("legacy_evidence", False),
    sample_count=breakdown.get("sample_count", "unknown"),
    metric_scores_json=json.dumps(breakdown.get("metric_scores", {}), sort_keys=True),
    weighted_components_json=json.dumps(breakdown.get("weighted_components", {}), sort_keys=True),
    focus_metrics_json=json.dumps(breakdown.get("focus_metrics", []), sort_keys=True),
    training_basis_json=json.dumps(context.get("training_basis", []), sort_keys=True),
    measurement_plan_json=json.dumps(context.get("measurement_plan", []), sort_keys=True),
    measurement_limits_json=json.dumps(context.get("measurement_limits", []), sort_keys=True),
    recording_evidence_json=json.dumps(breakdown.get("recording_evidence", {}), sort_keys=True),
    metric_details_json=json.dumps(breakdown.get("metric_details", {}), sort_keys=True),
    segments_json=json.dumps(breakdown.get("segments", []), sort_keys=True),
    strengths_json=json.dumps(strengths),
    improvements_json=json.dumps(improvements),
  )
