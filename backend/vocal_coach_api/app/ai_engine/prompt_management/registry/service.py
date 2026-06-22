import hashlib

from app.ai_engine.prompt_management.templates import v1
from app.ai_engine.prompt_management.templates import v1a
from app.ai_engine.prompt_management.templates import v1b

_PROMPT_RENDERERS = {
  "v1": v1,
  "v1a": v1a,
  "v1b": v1b,
}


def _ab_bucket(value: str) -> int:
  digest = hashlib.sha256(value.encode("utf-8")).hexdigest()
  return int(digest[:8], 16) % 100


def _resolve_prompt_version(prompt_version: str, session_id: str) -> str:
  normalized_version = (prompt_version or "v1").lower().strip()
  if normalized_version in _PROMPT_RENDERERS:
    return normalized_version
  if normalized_version in {"ab", "v1ab", "v1_ab"}:
    return "v1a" if _ab_bucket(session_id) < 50 else "v1b"
  return "v1"


def resolve_feedback_prompts(
  *,
  prompt_version: str,
  session_id: str,
  exercise_type: str,
  overall_score: float,
  metric_summary: dict[str, float | int],
  session_context: dict | None = None,
) -> tuple[str, str, str]:
  resolved_version = _resolve_prompt_version(prompt_version, session_id)
  renderer = _PROMPT_RENDERERS[resolved_version]

  system_prompt = renderer.SYSTEM_PROMPT
  user_prompt = renderer.render_user_prompt(
    session_id=session_id,
    exercise_type=exercise_type,
    overall_score=overall_score,
    metric_summary=metric_summary,
    session_context=session_context,
  )
  return system_prompt, user_prompt, resolved_version
