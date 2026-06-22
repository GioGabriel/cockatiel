from time import time

from fastapi import APIRouter, Depends

from app.ai_engine.orchestrator.service import generate_feedback
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
from app.modules.analytics.service import record_completed_session
from app.modules.sessions.service import (
  complete_session,
  create_session,
  evaluate_score,
  get_ai_feedback_context,
  get_session,
  mark_processing,
  summarize_metrics,
  upsert_ai_job,
  save_training_attempt,
)
from app.queue.producers.ai_evaluation import enqueue_ai_evaluation

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("", response_model=SessionCreateOut, status_code=201)
def start_session(payload: SessionCreateIn, current_user: dict = Depends(get_current_user)) -> SessionCreateOut:
  session = create_session(
    user_id=current_user["uid"],
    mode=payload.mode,
    exercise_type=payload.exercise_type,
    training_config=payload.training_config.model_dump(exclude_none=True) if payload.training_config else None,
  )
  return SessionCreateOut(session_id=session["session_id"], status=session["status"])


@router.get("/{session_id}", response_model=SessionOut)
def fetch_session(session_id: str, current_user: dict = Depends(get_current_user)) -> SessionOut:
  session = get_session(session_id=session_id, user_id=current_user["uid"])
  return SessionOut(**session)


@router.post("/{session_id}/finalize", response_model=FinalizeOut)
def finalize_session(session_id: str, current_user: dict = Depends(get_current_user)) -> FinalizeOut:
  session = get_session(session_id=session_id, user_id=current_user["uid"])
  if session["status"] not in {"started", "processing"}:
    raise ApiError(code="SESSION_STATE_INVALID", message="Session cannot be finalized.", status_code=409)
  if session.get("mode") == "training" and not list(session.get("attempts") or []):
    metric_summary = summarize_metrics(session_id)
    if int(metric_summary.get("sample_count") or 0) <= 0:
      raise ApiError(
        code="TRAINING_ATTEMPT_REQUIRED",
        message="Complete at least one training attempt before finalizing.",
        status_code=409,
      )

  if settings.ai_async_enabled:
    mark_processing(session_id=session_id, user_id=current_user["uid"])
    job = enqueue_ai_evaluation(session_id=session_id, user_id=current_user["uid"])
    now_ms = int(time() * 1000)
    upsert_ai_job(
      session_id=session_id,
      user_id=current_user["uid"],
      fields={
        "job_id": job["job_id"],
        "session_id": session_id,
        "mode": session["mode"],
        "exercise_type": session["exercise_type"],
        "state": "queued",
        "attempt": 0,
        "max_attempts": int(job.get("max_attempts", 1)),
        "queued_at": now_ms,
        "updated_at": now_ms,
        "last_error": None,
      },
    )
    return FinalizeOut(session_id=session_id, status="processing", feedback=None, job_id=job["job_id"])

  overall_score = evaluate_score(session_id)
  metric_summary = summarize_metrics(session_id)
  feedback_context = get_ai_feedback_context(session_id=session_id, user_id=current_user["uid"])
  feedback = generate_feedback(
    session_id=session_id,
    overall_score=overall_score,
    exercise_type=session["exercise_type"],
    metric_summary=metric_summary,
    session_context=feedback_context,
  )
  completed_session = complete_session(session_id=session_id, user_id=current_user["uid"], feedback=feedback)
  record_completed_session(current_user["uid"], completed_session)
  return FinalizeOut(session_id=session_id, status="completed", feedback=feedback)


@router.post("/{session_id}/attempts", response_model=TrainingAttemptSavedOut, status_code=201)
def save_attempt(
  session_id: str,
  payload: TrainingAttemptCreateIn,
  current_user: dict = Depends(get_current_user),
) -> TrainingAttemptSavedOut:
  saved = save_training_attempt(
    session_id=session_id,
    user_id=current_user["uid"],
    attempt_index=payload.attempt_index,
    difficulty=payload.difficulty,
    duration_sec=payload.duration_sec,
    metric_summary=payload.metric_summary.model_dump(),
  )
  return TrainingAttemptSavedOut.model_validate(saved)
