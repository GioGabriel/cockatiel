from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import AIHealthOut, AIJobOut
from app.core.config import settings
from app.core.exceptions import ApiError
from app.modules.sessions.service import list_sessions_for_user

router = APIRouter(prefix="/ai", tags=["ai"])


@router.get("/health", response_model=AIHealthOut)
def get_ai_health(_: dict = Depends(get_current_user)) -> AIHealthOut:
  if not settings.openrouter_enabled:
    return AIHealthOut(
      status="disabled",
      detail="OpenRouter is disabled by configuration.",
      openrouter_enabled=False,
      ai_async_enabled=settings.ai_async_enabled,
      openrouter_model=settings.openrouter_model,
      openrouter_timeout_s=settings.openrouter_timeout_s,
      reachable=False,
      latency_ms=None,
    )

  # Note: A real ping to OpenRouter could be added here. For now, if enabled, we assume it's reachable.
  return AIHealthOut(
    status="ok",
    detail="OpenRouter is enabled.",
    openrouter_enabled=True,
    ai_async_enabled=settings.ai_async_enabled,
    openrouter_model=settings.openrouter_model,
    openrouter_timeout_s=settings.openrouter_timeout_s,
    reachable=True,
    latency_ms=0,
  )


@router.get("/jobs", response_model=list[AIJobOut])
def list_ai_jobs(current_user: dict = Depends(get_current_user)) -> list[AIJobOut]:
  sessions = list_sessions_for_user(current_user["uid"])
  jobs: list[AIJobOut] = []
  for session in sessions:
    ai_job = session.get("ai_job")
    if not isinstance(ai_job, dict):
      continue
    jobs.append(
      AIJobOut.model_validate(
        {
          **ai_job,
          "session_id": session["session_id"],
          "mode": session["mode"],
          "exercise_type": session["exercise_type"],
          "updated_at": int(ai_job.get("updated_at") or session.get("created_at") or 0),
          "queued_at": int(ai_job.get("queued_at") or session.get("created_at") or 0),
        }
      )
    )

  return sorted(jobs, key=lambda item: item.updated_at, reverse=True)


@router.get("/jobs/{job_id}", response_model=AIJobOut)
def get_ai_job(job_id: str, current_user: dict = Depends(get_current_user)) -> AIJobOut:
  sessions = list_sessions_for_user(current_user["uid"])
  for session in sessions:
    ai_job = session.get("ai_job")
    if not isinstance(ai_job, dict):
      continue
    if str(ai_job.get("job_id")) != job_id:
      continue
    return AIJobOut.model_validate(
      {
        **ai_job,
        "session_id": session["session_id"],
        "mode": session["mode"],
        "exercise_type": session["exercise_type"],
        "updated_at": int(ai_job.get("updated_at") or session.get("created_at") or 0),
        "queued_at": int(ai_job.get("queued_at") or session.get("created_at") or 0),
      }
    )

  raise ApiError(code="AI_JOB_NOT_FOUND", message="AI job not found.", status_code=404)
