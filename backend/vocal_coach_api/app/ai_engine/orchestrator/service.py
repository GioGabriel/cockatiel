import logging
from time import perf_counter
from typing import Any

from pydantic import ValidationError

from app.api.v1.schemas import CoachingFeedback
from app.ai_engine.prompt_management.registry.service import resolve_feedback_prompts
from app.ai_engine.providers.openrouter_client import OpenRouterClient
from app.ai_engine.schemas.feedback_payload import LlmFeedbackPayload
from app.ai_engine.orchestrator.coaching_engine import CoachingLogicEngine
from app.core.config import settings
from app.observability.metrics.registry import increment, observe

logger = logging.getLogger("vocal-coach-api.ai")


def _metric_name_for_model(model: str) -> str:
  return "".join(char if char.isalnum() else "_" for char in model)


def _metric_name_for_prompt_version(prompt_version: str) -> str:
  return "".join(char if char.isalnum() else "_" for char in prompt_version)


def _metric_name_for_reason(reason: str) -> str:
  return "".join(char if char.isalnum() else "_" for char in reason.lower())


def _classify_model_exception(exc: Exception) -> str:
  if isinstance(exc, TimeoutError):
    return "timeout"
  message = str(exc).strip().lower()
  if "timed out" in message or "timeout" in message:
    return "timeout"
  if "http error" in message:
    return "http_error"
  if "connection failed" in message or "connection refused" in message:
    return "connection_error"
  if "invalid json" in message or "empty response" in message or "must be an object" in message:
    return "invalid_payload"
  return "unknown_error"


def generate_feedback(
  session_id: str,
  overall_score: float,
  exercise_type: str,
  metric_summary: dict[str, float | int],
  session_context: dict[str, Any] | None = None,
) -> CoachingFeedback:
  increment("ai_feedback_requests_total")
  start = perf_counter()

  # 1. Deterministic Coaching Logic Engine
  strengths, improvements, next_exercises = CoachingLogicEngine.evaluate(
    overall_score=overall_score,
    exercise_type=exercise_type,
    metric_summary=metric_summary,
  )

  model_used = "coaching-logic-engine"
  prompt_version = "v1"
  model_latency_ms = 0
  summary = None
  
  # 2. OpenRouter Conversational Summary
  if settings.openrouter_enabled and settings.openrouter_api_keys:
    system_prompt, user_prompt, resolved_prompt_version = resolve_feedback_prompts(
      prompt_version=settings.prompt_version,
      session_id=session_id,
      exercise_type=exercise_type,
      overall_score=overall_score,
      strengths=strengths,
      improvements=improvements,
    )
    prompt_version = resolved_prompt_version
    prompt_metric_suffix = _metric_name_for_prompt_version(prompt_version)

    try:
      client = OpenRouterClient(
        api_keys=settings.openrouter_api_keys,
        model=settings.openrouter_model,
        timeout_s=settings.openrouter_timeout_s,
        temperature=settings.openrouter_temperature,
      )
      payload, model_latency_ms = client.generate_json(system_prompt=system_prompt, user_prompt=user_prompt)
      validated_payload = LlmFeedbackPayload.model_validate(payload)
      summary = validated_payload.summary
      model_used = f"openrouter:{client.model}"
      
      increment("ai_feedback_success_total")
      increment(f"ai_feedback_success_prompt_{prompt_metric_suffix}_total")
      increment(f"ai_model_usage_openrouter_{_metric_name_for_model(client.model)}")
      observe("ai_feedback_latency_ms", model_latency_ms)

    except ValidationError as exc:
      logger.warning("openrouter_feedback_validation_failed session_id=%s error=%s", session_id, exc)
      increment("ai_feedback_validation_failure_total")
    except Exception as exc:
      logger.warning("openrouter_feedback_failed session_id=%s error=%s", session_id, exc)
      increment("ai_feedback_model_failure_total")
      failure_reason = _classify_model_exception(exc)
      increment(f"ai_feedback_model_failure_reason_{_metric_name_for_reason(failure_reason)}_total")

  total_latency_ms = int((perf_counter() - start) * 1000)

  return CoachingFeedback(
    session_id=session_id,
    overall_score=overall_score,
    strengths=strengths,
    improvements=improvements,
    next_exercises=next_exercises,
    summary=summary,
    model_used=model_used,
    prompt_version=prompt_version,
    latency_ms=total_latency_ms,
  )
