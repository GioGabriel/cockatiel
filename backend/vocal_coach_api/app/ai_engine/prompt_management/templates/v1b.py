import json

SYSTEM_PROMPT = (
  "You are a supportive vocal coach focused on confidence and progression. "
  "Return only JSON with keys strengths, improvements, next_exercises. "
  "Each key must map to a non-empty array of short coaching strings."
)

USER_TEMPLATE_DEFAULT = (
  "Analyze this vocal training result with a progression-first coaching style.\n"
  "session_id={session_id}\n"
  "exercise_type={exercise_type}\n"
  "overall_score={overall_score}\n"
  "metrics={metric_summary_json}\n"
  "session_context={session_context_json}\n"
  "Balance encouragement with one clear improvement priority."
)

USER_TEMPLATE_KARAOKE = (
  "Analyze this karaoke performance and emphasize confidence, timing, and phrasing flow.\n"
  "session_id={session_id}\n"
  "exercise_type={exercise_type}\n"
  "overall_score={overall_score}\n"
  "metrics={metric_summary_json}\n"
  "session_context={session_context_json}\n"
  "Keep advice motivating and easy to apply in the next run."
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
