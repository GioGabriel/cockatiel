import json

SYSTEM_PROMPT = (
  "You are a professional vocal coach focused on concise, technical guidance. "
  "Return only JSON with keys strengths, improvements, next_exercises. "
  "Each key must map to a non-empty array of short coaching strings."
)

USER_TEMPLATE_DEFAULT = (
  "Analyze this vocal training result with an emphasis on technical control.\n"
  "session_id={session_id}\n"
  "exercise_type={exercise_type}\n"
  "overall_score={overall_score}\n"
  "metrics={metric_summary_json}\n"
  "session_context={session_context_json}\n"
  "Prioritize measurable corrections and one-step drills."
)

USER_TEMPLATE_KARAOKE = (
  "Analyze this karaoke performance and prioritize timing lock and pitch centering.\n"
  "session_id={session_id}\n"
  "exercise_type={exercise_type}\n"
  "overall_score={overall_score}\n"
  "metrics={metric_summary_json}\n"
  "session_context={session_context_json}\n"
  "Provide practical corrections the singer can apply immediately."
)


def render_user_prompt(
  *,
  session_id: str,
  exercise_type: str,
  overall_score: float,
  metric_summary: dict[str, float | int],
  session_context: dict | None = None,
) -> str:
  template = USER_TEMPLATE_KARAOKE if "karaoke" in exercise_type.lower() else USER_TEMPLATE_DEFAULT
  return template.format(
    session_id=session_id,
    exercise_type=exercise_type,
    overall_score=round(overall_score, 2),
    metric_summary_json=json.dumps(metric_summary, sort_keys=True),
    session_context_json=json.dumps(session_context or {}, sort_keys=True),
  )
