import logging

from time import time

from app.ai_engine.orchestrator.service import generate_feedback
from app.modules.analytics.service import record_completed_session
from app.modules.sessions.service import complete_session, evaluate_score, get_ai_feedback_context, get_session, mark_failed, summarize_metrics, upsert_ai_job
from app.observability.metrics.registry import increment, observe
from app.queue.tasks.ai_evaluation_queue import dequeue, requeue, size

logger = logging.getLogger("vocal-coach-api.ai-queue-consumer")


def process_next_ai_evaluation_job() -> bool:
  job = dequeue()
  if not job:
    return False

  observe("ai_queue_depth", float(size()))
  increment("ai_queue_dequeued_total")

  session_id = str(job.get("session_id", ""))
  user_id = str(job.get("user_id", ""))
  attempt = int(job.get("attempt", 0))
  max_attempts = max(int(job.get("max_attempts", 1)), 1)
  logger.info(
    "ai_queue_job_started session_id=%s user_id=%s attempt=%s max_attempts=%s",
    session_id,
    user_id,
    attempt,
    max_attempts,
  )

  try:
    session = get_session(session_id=session_id, user_id=user_id)
    now_ms = int(time() * 1000)
    upsert_ai_job(
      session_id=session_id,
      user_id=user_id,
      fields={
        "state": "processing",
        "attempt": attempt,
        "max_attempts": max_attempts,
        "started_at": now_ms,
        "updated_at": now_ms,
      },
    )
    if session.get("status") == "completed":
      increment("ai_queue_job_skipped_total")
      return True

    overall_score = evaluate_score(session_id)
    metric_summary = summarize_metrics(session_id)
    feedback_context = get_ai_feedback_context(session_id=session_id, user_id=user_id)
    feedback = generate_feedback(
      session_id=session_id,
      overall_score=overall_score,
      exercise_type=str(session.get("exercise_type", "training")),
      metric_summary=metric_summary,
      session_context=feedback_context,
    )
    completed = complete_session(session_id=session_id, user_id=user_id, feedback=feedback)
    record_completed_session(user_id, completed)
    increment("ai_queue_job_completed_total")
    logger.info(
      "ai_queue_job_completed session_id=%s user_id=%s model_used=%s",
      session_id,
      user_id,
      feedback.model_used,
    )
    return True
  except Exception as exc:
    if attempt + 1 >= max_attempts:
      try:
        mark_failed(session_id=session_id, user_id=user_id, reason=str(exc))
      except Exception:
        pass
      increment("ai_queue_job_failed_total")
      logger.warning(
        "ai_queue_job_failed session_id=%s user_id=%s attempt=%s error=%s",
        session_id,
        user_id,
        attempt,
        exc,
      )
      return True

    requeue(job, error=str(exc))
    upsert_ai_job(
      session_id=session_id,
      user_id=user_id,
      fields={
        "state": "queued",
        "attempt": attempt + 1,
        "max_attempts": max_attempts,
        "updated_at": int(time() * 1000),
        "last_error": str(exc),
      },
    )
    increment("ai_queue_job_retried_total")
    observe("ai_queue_depth", float(size()))
    logger.warning(
      "ai_queue_job_retried session_id=%s user_id=%s next_attempt=%s error=%s",
      session_id,
      user_id,
      attempt + 1,
      exc,
    )
    return True
