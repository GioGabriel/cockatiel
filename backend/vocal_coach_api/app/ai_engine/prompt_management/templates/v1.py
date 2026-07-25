import json

SYSTEM_PROMPT = (
  "You are a professional, encouraging vocal coach. "
  "Based on the user's score and the technical feedback points provided, write a short, friendly 1-2 sentence summary of their performance. "
  "Return ONLY a JSON object with a single key 'summary'."
)

USER_TEMPLATE = (
  "Score: {overall_score}/100\n"
  "Exercise: {exercise_type}\n"
  "Strengths: {strengths_json}\n"
  "Improvements needed: {improvements_json}\n"
)


def render_user_prompt(
  *,
  overall_score: float,
  exercise_type: str,
  strengths: list[str],
  improvements: list[str],
) -> str:
  return USER_TEMPLATE.format(
    overall_score=round(overall_score, 2),
    exercise_type=exercise_type,
    strengths_json=json.dumps(strengths),
    improvements_json=json.dumps(improvements),
  )
