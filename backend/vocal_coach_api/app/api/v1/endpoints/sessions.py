import asyncio
from time import time
from uuid import uuid4
from fastapi import APIRouter, Depends

from fastapi.concurrency import run_in_threadpool

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import (
  FinalizeOut,
  SessionCreateIn,
  SessionCreateOut,
  SessionOut,
  TrainingAttemptCreateIn,
  TrainingAttemptSavedOut,
)
from app.core.config import settings
from app.core.exceptions import ApiError
from app.modules.sessions.service import SessionService
from app.queue.producers.ai_evaluation import enqueue_ai_evaluation


def get_session_service() -> SessionService:
  return SessionService()


_finalize_locks: dict[str, asyncio.Lock] = {}

def get_finalize_lock(session_id: str) -> asyncio.Lock:
  if session_id not in _finalize_locks:
    _finalize_locks[session_id] = asyncio.Lock()
  return _finalize_locks[session_id]

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("", response_model=SessionCreateOut, status_code=201)
async def start_session(
  payload: SessionCreateIn,
  current_user: dict = Depends(get_current_user),
  svc: SessionService = Depends(get_session_service),
) -> SessionCreateOut:
  session = await run_in_threadpool(
    svc.create_session,
    user_id=current_user["uid"],
    mode=payload.mode,
    exercise_type=payload.exercise_type,
    training_config=payload.training_config.model_dump(exclude_none=True) if payload.training_config else None,
  )
  return SessionCreateOut(session_id=session["session_id"], status=session["status"])


@router.get("/{session_id}", response_model=SessionOut)
async def fetch_session(
  session_id: str,
  current_user: dict = Depends(get_current_user),
  svc: SessionService = Depends(get_session_service),
) -> SessionOut:
  session = await run_in_threadpool(svc.get_session, session_id=session_id, user_id=current_user["uid"])
  return SessionOut(**session)


@router.post("/{session_id}/finalize", response_model=FinalizeOut)
async def finalize_session(
  session_id: str,
  current_user: dict = Depends(get_current_user),
  svc: SessionService = Depends(get_session_service),
) -> FinalizeOut:
  lock = get_finalize_lock(session_id)
  async with lock:
    session = await run_in_threadpool(svc.get_session, session_id=session_id, user_id=current_user["uid"])
    if session["status"] not in {"started", "processing"}:
      raise ApiError(code="SESSION_STATE_INVALID", message="Session cannot be finalized.", status_code=409)
    
    if session.get("mode") == "training" and not session.get("attempts"):
      metric_summary = await run_in_threadpool(svc.summarize_metrics, session_id)
      if int(metric_summary.get("sample_count") or 0) <= 0:
        raise ApiError(
          code="TRAINING_ATTEMPT_REQUIRED",
          message="Complete at least one training attempt before finalizing.",
          status_code=409,
        )

    if settings.ai_async_enabled:
      job_id = str(uuid4())
      now_ms = int(time() * 1000)

      try:
        await asyncio.wait_for(
          run_in_threadpool(svc.mark_processing, session_id=session_id, user_id=current_user["uid"]),
          timeout=10.0
        )
        
        await asyncio.wait_for(
          run_in_threadpool(
            svc.upsert_ai_job,
            session_id=session_id,
            user_id=current_user["uid"],
            fields={
              "job_id": job_id,
              "session_id": session_id,
              "mode": session["mode"],
              "exercise_type": session["exercise_type"],
              "state": "pending_enqueue",
              "attempt": 0,
              "max_attempts": 1,
              "queued_at": now_ms,
              "updated_at": now_ms,
              "last_error": None,
            },
          ),
          timeout=10.0
        )

        job = await asyncio.wait_for(
          run_in_threadpool(enqueue_ai_evaluation, session_id=session_id, user_id=current_user["uid"], job_id=job_id),
          timeout=10.0
        )

        await asyncio.wait_for(
          run_in_threadpool(
            svc.upsert_ai_job,
            session_id=session_id,
            user_id=current_user["uid"],
            fields={
              "state": "queued",
              "max_attempts": int(job.get("max_attempts", 1)),
              "updated_at": int(time() * 1000),
            },
          ),
          timeout=10.0
        )
      except asyncio.TimeoutError:
        raise ApiError(code="GATEWAY_TIMEOUT", message="The database or queue did not respond in time.", status_code=504)

      return FinalizeOut(session_id=session_id, status="processing", feedback=None, job_id=job_id)

    result = await run_in_threadpool(svc.finalize_session_logic, session_id, current_user["uid"])
    return FinalizeOut(**result)


@router.post("/{session_id}/attempts", response_model=TrainingAttemptSavedOut, status_code=201)
async def save_attempt(
  session_id: str,
  payload: TrainingAttemptCreateIn,
  current_user: dict = Depends(get_current_user),
  svc: SessionService = Depends(get_session_service),
) -> TrainingAttemptSavedOut:
  saved = await run_in_threadpool(
    svc.save_training_attempt,
    session_id=session_id,
    user_id=current_user["uid"],
    attempt_index=payload.attempt_index,
    difficulty=payload.difficulty,
    duration_sec=payload.duration_sec,
    metric_summary=payload.metric_summary.model_dump(),
  )
  return TrainingAttemptSavedOut.model_validate(saved)
