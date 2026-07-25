from time import time
from typing import Any
from uuid import uuid4

from app.api.v1.schemas import CanonicalMetric, CoachingFeedback
from app.core.exceptions import ApiError
from app.repositories.provider import get_session_repository
from app.modules.training.scoring import (
  VOICE_METRIC_FIELDS,
  metric_fields_for_exercise,
  metric_mode_for_exercise,
  score_training_attempt,
)
from app.modules.training.service import build_ai_feedback_context, build_training_session_metadata


def finalize_session_logic(session_id: str, user_id: str) -> dict[str, Any]:
  overall_score = evaluate_score(session_id)
  metric_summary = summarize_metrics(session_id)
  feedback_context = get_ai_feedback_context(session_id=session_id, user_id=user_id)
  
  from app.ai_engine.orchestrator.service import generate_feedback
  feedback = generate_feedback(
    session_id=session_id,
    overall_score=overall_score,
    exercise_type=get_session(session_id, user_id)["exercise_type"],
    metric_summary=metric_summary,
    session_context=feedback_context,
  )
  completed_session = complete_session(session_id=session_id, user_id=user_id, feedback=feedback)
  
  from app.modules.analytics.service import record_completed_session
  record_completed_session(user_id, completed_session)
  return {"session_id": session_id, "status": "completed", "feedback": feedback}


class SessionService:
  def create_session(self, *args, **kwargs):
    return create_session(*args, **kwargs)

  def get_session(self, *args, **kwargs):
    return get_session(*args, **kwargs)

  def summarize_metrics(self, *args, **kwargs):
    return summarize_metrics(*args, **kwargs)

  def finalize_session_logic(self, *args, **kwargs):
    return finalize_session_logic(*args, **kwargs)

  def mark_processing(self, *args, **kwargs):
    return mark_processing(*args, **kwargs)

  def upsert_ai_job(self, *args, **kwargs):
    return upsert_ai_job(*args, **kwargs)

  def save_training_attempt(self, *args, **kwargs):
    return save_training_attempt(*args, **kwargs)

  def get_ai_feedback_context(self, *args, **kwargs):
    return get_ai_feedback_context(*args, **kwargs)


def create_session(
  user_id: str,
  mode: str,
  exercise_type: str,
  training_config: dict[str, Any] | None = None,
) -> dict[str, Any]:
  repository = get_session_repository()
  session_id = str(uuid4())

  training_metadata: dict[str, Any] = {}
  if mode == "training":
    training_metadata = build_training_session_metadata(
      exercise_id=exercise_type,
      training_config=training_config,
    )
  elif mode == "karaoke":
    from app.modules.karaoke.service import build_karaoke_session_metadata
    training_metadata = build_karaoke_session_metadata(exercise_type)

  record = {
    "session_id": session_id,
    "user_id": user_id,
    "mode": mode,
    "exercise_type": exercise_type,
    "status": "started",
    "overall_score": None,
    "feedback": None,
    "created_at": int(time() * 1000),
    "ai_job": None,
    "attempts": [] if mode == "training" else None,
    "selected_best_attempt_id": None,
    "best_attempt_score": None,
    **training_metadata,
  }
  return repository.create(record)


def list_sessions_for_user(user_id: str) -> list[dict[str, Any]]:
  repository = get_session_repository()
  sessions = repository.list_by_user(user_id)
  normalized: list[dict[str, Any]] = []
  for session in sessions:
    feedback = session.get("feedback")
    if isinstance(feedback, dict):
      session["feedback"] = CoachingFeedback.model_validate(feedback)
    ai_job = session.get("ai_job")
    if isinstance(ai_job, dict) and not ai_job.get("job_id"):
      session["ai_job"] = None
    if not isinstance(session.get("attempts"), list):
      session["attempts"] = []
    normalized.append(session)
  return normalized


def get_session(session_id: str, user_id: str) -> dict[str, Any]:
  repository = get_session_repository()
  session = repository.get(session_id)
  if not session or session["user_id"] != user_id:
    raise ApiError(code="SESSION_NOT_FOUND", message="Session not found.", status_code=404)
  feedback = session.get("feedback")
  if isinstance(feedback, dict):
    session["feedback"] = CoachingFeedback.model_validate(feedback)
  ai_job = session.get("ai_job")
  if isinstance(ai_job, dict) and not ai_job.get("job_id"):
    session["ai_job"] = None
  if not isinstance(session.get("attempts"), list):
    session["attempts"] = []
  return session


def get_ai_feedback_context(session_id: str, user_id: str) -> dict[str, Any]:
  session = get_session(session_id, user_id)
  return build_ai_feedback_context(session)


def append_metrics(session_id: str, user_id: str, metrics: list[CanonicalMetric]) -> int:
  repository = get_session_repository()
  session = get_session(session_id, user_id)
  for metric in metrics:
    if metric.session_id != session["session_id"]:
      raise ApiError(
        code="SESSION_ID_MISMATCH",
        message="Metric session_id does not match route sessionId.",
        status_code=400,
      )
  return repository.append_metrics(session_id, [metric.model_dump() for metric in metrics])


def summarize_metrics(session_id: str) -> dict[str, float | int]:
  repository = get_session_repository()
  session = repository.get(session_id)
  if session and isinstance(session.get("attempts"), list):
    attempts = [item for item in session["attempts"] if isinstance(item, dict)]
    selected_best_attempt_id = str(session.get("selected_best_attempt_id") or "")
    if attempts and selected_best_attempt_id:
      selected = next(
        (item for item in attempts if str(item.get("attempt_id")) == selected_best_attempt_id),
        None,
      )
      if selected and isinstance(selected.get("metric_summary"), dict):
        metric_summary = dict(selected["metric_summary"])
        saved_at = int(selected.get("saved_at") or session.get("created_at") or 0)
        metric_summary["first_timestamp_ms"] = saved_at
        metric_summary["last_timestamp_ms"] = saved_at
        return metric_summary

  metrics = repository.list_metrics(session_id)
  if not metrics:
    return {
      "metric_mode": "voice",
      "sample_count": 0,
      "first_timestamp_ms": 0,
      "last_timestamp_ms": 0,
      "pitch_accuracy": 0.0,
      "timing_accuracy": 0.0,
      "breath_control": 0.0,
      "pitch_stability": 0.0,
      "vibrato_consistency": 0.0,
      "note_transition_smoothness": 0.0,
      "overall_score": 0.0,
    }

  timestamps = [int(item.get("timestamp_ms", 0)) for item in metrics]
  summary: dict[str, float | int] = {
    "metric_mode": "voice",
    "sample_count": len(metrics),
    "first_timestamp_ms": min(timestamps),
    "last_timestamp_ms": max(timestamps),
  }
  for field in VOICE_METRIC_FIELDS:
    summary[field] = round(sum(float(item.get(field, 0.0)) for item in metrics) / len(metrics), 2)
  summary["overall_score"] = round(
    sum(float(summary[field]) for field in VOICE_METRIC_FIELDS) / len(VOICE_METRIC_FIELDS),
    2,
  )
  return summary


def evaluate_score(session_id: str) -> float:
  summary = summarize_metrics(session_id)
  return float(summary["overall_score"])


def complete_session(session_id: str, user_id: str, feedback: CoachingFeedback) -> dict[str, Any]:
  repository = get_session_repository()
  session = get_session(session_id, user_id)
  metric_summary = summarize_metrics(session_id)
  now_ms = int(time() * 1000)
  last_metric_timestamp_ms = int(metric_summary.get("last_timestamp_ms") or 0)
  completed_at = last_metric_timestamp_ms if last_metric_timestamp_ms >= 946684800000 else now_ms
  ai_job = session.get("ai_job")
  ai_job_update = {
    **(ai_job if isinstance(ai_job, dict) else {}),
    "state": "completed",
    "updated_at": now_ms,
    "completed_at": completed_at,
  } if isinstance(ai_job, dict) and ai_job.get("job_id") else None

  updates: dict[str, Any] = {
    "status": "completed",
    "overall_score": feedback.overall_score,
    "metrics_summary": metric_summary,
    "feedback": feedback.model_dump(),
    "completed_at": completed_at,
  }
  if ai_job_update is not None:
    updates["ai_job"] = ai_job_update

  updated = repository.update(
    session_id,
    updates,
  )
  if not updated:
    raise ApiError(code="SESSION_NOT_FOUND", message="Session not found.", status_code=404)
  updated["feedback"] = feedback
  return updated


def mark_failed(session_id: str, user_id: str, reason: str) -> dict[str, Any]:
  repository = get_session_repository()
  session = get_session(session_id, user_id)
  now_ms = int(time() * 1000)
  ai_job = session.get("ai_job")
  ai_job_update = {
    **(ai_job if isinstance(ai_job, dict) else {}),
    "state": "failed",
    "updated_at": now_ms,
    "last_error": reason,
  } if isinstance(ai_job, dict) and ai_job.get("job_id") else None

  updates: dict[str, Any] = {
    "status": "failed",
    "failure_reason": reason,
    "failed_at": now_ms,
  }
  if ai_job_update is not None:
    updates["ai_job"] = ai_job_update

  updated = repository.update(
    session_id,
    updates,
  )
  if not updated:
    raise ApiError(code="SESSION_NOT_FOUND", message="Session not found.", status_code=404)
  return updated


def mark_processing(session_id: str, user_id: str) -> dict[str, Any]:
  repository = get_session_repository()
  get_session(session_id, user_id)
  updated = repository.update(session_id, {"status": "processing"})
  if not updated:
    raise ApiError(code="SESSION_NOT_FOUND", message="Session not found.", status_code=404)
  return updated


def upsert_ai_job(session_id: str, user_id: str, fields: dict[str, Any]) -> dict[str, Any]:
  repository = get_session_repository()
  session = get_session(session_id, user_id)
  current = session.get("ai_job")
  merged = {**(current or {}), **fields}
  updated = repository.update(session_id, {"ai_job": merged})
  if not updated:
    raise ApiError(code="SESSION_NOT_FOUND", message="Session not found.", status_code=404)
  return updated


def save_training_attempt(
  session_id: str,
  user_id: str,
  *,
  attempt_index: int,
  difficulty: str,
  duration_sec: int,
  metric_summary: dict[str, float | int],
) -> dict[str, Any]:
  session = get_session(session_id, user_id)
  if session.get("mode") != "training":
    raise ApiError(
      code="SESSION_MODE_INVALID",
      message="Training attempts can only be saved for training sessions.",
      status_code=409,
    )

  attempts = list(session.get("attempts") or [])
  max_attempts = int((session.get("attempt_policy") or {}).get("max_attempts") or 3)
  if len(attempts) >= max_attempts:
    raise ApiError(
      code="MAX_ATTEMPTS_REACHED",
      message="Maximum attempts reached for this session.",
      status_code=409,
    )
  if attempt_index != len(attempts) + 1:
    raise ApiError(
      code="ATTEMPT_INDEX_INVALID",
      message="Attempt index must match the next attempt number for this session.",
      status_code=409,
    )

  resolved_exercise_id = str(session.get("exercise_id") or session.get("exercise_type") or "training")
  expected_metric_mode = metric_mode_for_exercise(resolved_exercise_id)
  provided_metric_mode = str(metric_summary.get("metric_mode") or expected_metric_mode).strip().lower()
  if provided_metric_mode != expected_metric_mode:
    raise ApiError(
      code="TRAINING_METRIC_MODE_INVALID",
      message="Metric summary mode does not match the exercise mode for this session.",
      status_code=400,
    )

  required_fields = list(metric_fields_for_exercise(resolved_exercise_id))
  summary: dict[str, float | int | str] = {
    "metric_mode": expected_metric_mode,
  }
  for field in required_fields:
    summary[field] = round(float(metric_summary.get(field, 0.0)), 2)
  sample_count = int(metric_summary.get("sample_count") or 1)
  summary["sample_count"] = max(sample_count, 1)
  if expected_metric_mode == "breathing":
    summary["interruption_count"] = max(0, int(metric_summary.get("interruption_count") or 0))
  scoring = score_training_attempt(
    exercise_id=resolved_exercise_id,
    metric_summary=summary,
  )
  summary["overall_score"] = float(scoring["overall_score"])

  attempt_id = str(uuid4())
  saved_at = int(time() * 1000)
  attempt = {
    "attempt_id": attempt_id,
    "attempt_index": attempt_index,
    "difficulty": difficulty,
    "duration_sec": duration_sec,
    "score": float(scoring["overall_score"]),
    "metric_summary": summary,
    "score_breakdown": scoring["score_breakdown"],
    "strongest_metric": scoring["strongest_metric"],
    "weakest_metric": scoring["weakest_metric"],
    "passed_threshold": scoring["passed_threshold"],
    "saved_at": saved_at,
    "is_best": False,
  }
  attempts.append(attempt)

  best_attempt = max(attempts, key=lambda item: float(item.get("score") or 0))
  selected_best_attempt_id = str(best_attempt.get("attempt_id") or attempt_id)
  best_attempt_score = round(float(best_attempt.get("score") or scoring["overall_score"]), 2)

  for item in attempts:
    item["is_best"] = str(item.get("attempt_id")) == selected_best_attempt_id

  repository = get_session_repository()
  updated = repository.update(
    session_id,
    {
      "attempts": attempts,
      "selected_best_attempt_id": selected_best_attempt_id,
      "best_attempt_score": best_attempt_score,
    },
  )
  if not updated:
    raise ApiError(code="SESSION_NOT_FOUND", message="Session not found.", status_code=404)

  selected_attempt = next(
    item for item in attempts if str(item.get("attempt_id")) == selected_best_attempt_id
  )
  return {
    "session_id": session_id,
    "attempt": attempt,
    "selected_best_attempt_id": selected_best_attempt_id,
    "best_attempt_score": best_attempt_score,
    "selected_attempt": selected_attempt,
  }
