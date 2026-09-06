import logging
from time import perf_counter
from typing import Any

from pydantic import ValidationError

from app.api.v1.schemas import CoachingFeedback, DetailedImprovement
from app.ai_engine.prompt_management.registry.service import resolve_feedback_prompts
from app.ai_engine.providers.google_ai_client import GoogleAiStudioClient
from app.ai_engine.schemas.feedback_payload import LlmFeedbackPayload
from app.ai_engine.orchestrator.coaching_engine import CoachingLogicEngine
from app.core.config import settings
from app.modules.training.scoring import score_training_attempt
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
  metric_summary: dict[str, Any],
  session_context: dict[str, Any] | None = None,
  score_breakdown: dict[str, Any] | None = None,
) -> CoachingFeedback:
  increment("ai_feedback_requests_total")
  start = perf_counter()

  if score_breakdown is None:
    score_breakdown = score_training_attempt(
      exercise_id=exercise_type,
      metric_summary=metric_summary,
    )["score_breakdown"]

  # 1. Deterministic Coaching Logic Engine
  strengths, improvements, next_exercises = CoachingLogicEngine.evaluate(
    overall_score=overall_score,
    exercise_type=exercise_type,
    metric_summary=metric_summary,
  )

  model_used = "coaching-logic-engine"
  prompt_version = settings.prompt_version
  model_latency_ms = 0
  summary = None
  detailed_improvements = CoachingLogicEngine.build_detailed_improvements(
    exercise_type=exercise_type,
    metric_summary=metric_summary,
    score_breakdown=score_breakdown,
  )
  
  # 2. Google AI Studio conversational summary. This remains optional; the
  # deterministic engine above is authoritative and always produces feedback.
  if settings.google_ai_enabled and settings.google_api_keys:
    system_prompt, user_prompt, resolved_prompt_version = resolve_feedback_prompts(
      prompt_version=settings.prompt_version,
      session_id=session_id,
      exercise_type=exercise_type,
      overall_score=overall_score,
      strengths=strengths,
      improvements=improvements,
      score_breakdown=score_breakdown,
      exercise_context=session_context,
    )
    prompt_version = resolved_prompt_version
    prompt_metric_suffix = _metric_name_for_prompt_version(prompt_version)

    try:
      client = GoogleAiStudioClient(
        api_keys=settings.google_api_keys,
        model=settings.google_ai_model,
        timeout_s=settings.google_ai_timeout_s,
        temperature=settings.google_ai_temperature,
        max_output_tokens=settings.google_ai_max_output_tokens,
        fallback_models=settings.google_ai_fallback_models,
        max_total_time_s=getattr(settings, "google_ai_max_total_time_s", settings.google_ai_timeout_s),
      )
      payload, model_latency_ms = client.generate_json(system_prompt=system_prompt, user_prompt=user_prompt)
      validated_payload = LlmFeedbackPayload.model_validate(payload)
      allowed_metric_keys = set((score_breakdown.get("metric_scores") or {}).keys())
      provider_improvements = [
        item.model_dump()
        for item in validated_payload.detailed_improvements
      ]
      if any(item["metric_key"] not in allowed_metric_keys for item in provider_improvements):
        raise ValueError("Google AI returned an improvement for an unknown metric.")
      summary = validated_payload.summary
      detailed_improvements = provider_improvements
      model_used = f"google-ai-studio:{client.model}"
      
      increment("ai_feedback_success_total")
      increment(f"ai_feedback_success_prompt_{prompt_metric_suffix}_total")
      increment(f"ai_model_usage_google_ai_{_metric_name_for_model(client.model)}")
      observe("ai_feedback_latency_ms", model_latency_ms)
      logger.info(
        "google_ai_feedback_succeeded session_id=%s model=%s prompt_version=%s latency_ms=%s improvement_count=%s",
        session_id,
        client.model,
        prompt_version,
        model_latency_ms,
        len(provider_improvements),
      )

    except ValidationError as exc:
      logger.warning(
        "google_ai_feedback_validation_failed session_id=%s error_type=%s",
        session_id,
        type(exc).__name__,
      )
      increment("ai_feedback_validation_failure_total")
    except Exception as exc:
      logger.warning(
        "google_ai_feedback_failed session_id=%s error_type=%s",
        session_id,
        type(exc).__name__,
      )
      increment("ai_feedback_model_failure_total")
      failure_reason = _classify_model_exception(exc)
      increment(f"ai_feedback_model_failure_reason_{_metric_name_for_reason(failure_reason)}_total")

  if not summary:
    summary = CoachingLogicEngine.generate_fallback_summary(
      overall_score=overall_score,
      exercise_type=exercise_type,
      metric_summary=metric_summary,
      strengths=strengths,
      improvements=improvements,
      score_breakdown=score_breakdown,
    )
    detailed_improvements = CoachingLogicEngine.build_detailed_improvements(
      exercise_type=exercise_type,
      metric_summary=metric_summary,
      score_breakdown=score_breakdown,
    )
    if model_used == "coaching-logic-engine" and settings.google_ai_enabled and settings.google_api_keys:
      model_used = "coaching-logic-engine-fallback"
    increment("ai_feedback_fallback_total")
    increment(f"ai_feedback_fallback_prompt_{_metric_name_for_prompt_version(prompt_version)}_total")
    fallback_reason = "google_ai_unavailable" if settings.google_ai_enabled else "google_ai_disabled"
    increment(f"ai_feedback_fallback_reason_{_metric_name_for_reason(fallback_reason)}_total")

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
    score_breakdown=score_breakdown,
    detailed_improvements=[
      DetailedImprovement.model_validate(item)
      for item in detailed_improvements[:3]
    ],
  )
