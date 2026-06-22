from fastapi import APIRouter, Depends

from app.ai_engine.model_router.service import OllamaModelRouter
from app.ai_engine.providers.ollama_health import list_ollama_models
from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import AIHealthOut, AIJobOut, AIModelStatusOut
from app.core.config import settings
from app.core.exceptions import ApiError
from app.modules.sessions.service import list_sessions_for_user

router = APIRouter(prefix="/ai", tags=["ai"])


@router.get("/health", response_model=AIHealthOut)
def get_ai_health(_: dict = Depends(get_current_user)) -> AIHealthOut:
  candidate_models = list(OllamaModelRouter(settings.ollama_models).candidates())

  if not settings.ollama_enabled:
    return AIHealthOut(
      status="disabled",
      detail="Ollama is disabled by configuration.",
      ollama_enabled=False,
      ai_async_enabled=settings.ai_async_enabled,
      ollama_base_url=settings.ollama_base_url,
      ollama_timeout_s=settings.ollama_timeout_s,
      configured_models=list(settings.ollama_models),
      available_models=[],
      candidate_models=[AIModelStatusOut(model=model, available=False) for model in candidate_models],
      reachable=False,
      latency_ms=None,
    )

  try:
    available_models, latency_ms = list_ollama_models(
      base_url=settings.ollama_base_url,
      timeout_s=settings.ollama_timeout_s,
    )
    available_set = set(available_models)
    model_statuses = [
      AIModelStatusOut(model=model, available=model in available_set)
      for model in candidate_models
    ]

    if not candidate_models:
      status = "degraded"
      detail = "No candidate models configured."
    elif any(item.available for item in model_statuses):
      status = "ok"
      detail = "Ollama reachable and at least one configured model is available."
    else:
      status = "degraded"
      detail = "Ollama reachable but configured models are not available."

    return AIHealthOut(
      status=status,
      detail=detail,
      ollama_enabled=True,
      ai_async_enabled=settings.ai_async_enabled,
      ollama_base_url=settings.ollama_base_url,
      ollama_timeout_s=settings.ollama_timeout_s,
      configured_models=list(settings.ollama_models),
      available_models=available_models,
      candidate_models=model_statuses,
      reachable=True,
      latency_ms=latency_ms,
    )
  except Exception as exc:
    return AIHealthOut(
      status="degraded",
      detail=f"Ollama unavailable: {exc}",
      ollama_enabled=True,
      ai_async_enabled=settings.ai_async_enabled,
      ollama_base_url=settings.ollama_base_url,
      ollama_timeout_s=settings.ollama_timeout_s,
      configured_models=list(settings.ollama_models),
      available_models=[],
      candidate_models=[AIModelStatusOut(model=model, available=False) for model in candidate_models],
      reachable=False,
      latency_ms=None,
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
