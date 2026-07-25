import hashlib

from app.ai_engine.prompt_management.templates import v1

_PROMPT_RENDERERS = {
  "v1": v1,
}

def _resolve_prompt_version(prompt_version: str, session_id: str) -> str:
  return "v1"

def resolve_feedback_prompts(
  *,
  prompt_version: str,
  session_id: str,
  exercise_type: str,
  overall_score: float,
  strengths: list[str],
  improvements: list[str],
) -> tuple[str, str, str]:
  resolved_version = _resolve_prompt_version(prompt_version, session_id)
  renderer = _PROMPT_RENDERERS[resolved_version]

  system_prompt = renderer.SYSTEM_PROMPT
  user_prompt = renderer.render_user_prompt(
    overall_score=overall_score,
    exercise_type=exercise_type,
    strengths=strengths,
    improvements=improvements,
  )
  return system_prompt, user_prompt, resolved_version
