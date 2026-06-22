import logging
from time import perf_counter
from typing import Any

from pydantic import ValidationError

from app.api.v1.schemas import CoachingFeedback
from app.ai_engine.model_router.service import OllamaModelRouter
from app.ai_engine.prompt_management.registry.service import resolve_feedback_prompts
from app.ai_engine.providers.ollama_client import OllamaClient
from app.ai_engine.providers.openrouter_client import OpenRouterClient
from app.ai_engine.schemas.feedback_payload import LlmFeedbackPayload
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


def _fallback_feedback(
  *,
  session_id: str,
  overall_score: float,
  exercise_type: str,
  prompt_version: str,
  latency_ms: int,
) -> CoachingFeedback:
  strengths: list[str] = []
  improvements: list[str] = []
  next_exercises: list[str] = []

  if overall_score >= 80:
    strengths.append("Strong intonation consistency")
    next_exercises.append("Dynamic phrasing exercise")
  else:
    improvements.append("Pitch center drifts on sustained notes")
    next_exercises.append("Slow interval matching drill")

  if exercise_type.lower() == "karaoke":
    next_exercises.append("Timing lock with metronome")
  else:
    next_exercises.append("Breath pacing ladder")

  if not strengths:
    strengths.append("Good training consistency")
  if not improvements:
    improvements.append("Refine note transitions")

  return CoachingFeedback(
    session_id=session_id,
    overall_score=overall_score,
    strengths=strengths,
    improvements=improvements,
    next_exercises=next_exercises,
    model_used="fallback-rules",
    prompt_version=prompt_version,
    latency_ms=latency_ms,
  )


def _coerce_feedback_payload(
  *,
  payload: dict[str, Any],
  session_id: str,
  overall_score: float,
  model_used: str,
  prompt_version: str,
  latency_ms: int,
) -> CoachingFeedback:
  validated_payload = LlmFeedbackPayload.model_validate(payload)
  normalized = {
    "session_id": session_id,
    "overall_score": overall_score,
    "strengths": validated_payload.strengths,
    "improvements": validated_payload.improvements,
    "next_exercises": validated_payload.next_exercises,
    "model_used": model_used,
    "prompt_version": prompt_version,
    "latency_ms": latency_ms,
  }
  return CoachingFeedback.model_validate(normalized)


def generate_feedback(
  session_id: str,
  overall_score: float,
  exercise_type: str,
  metric_summary: dict[str, float | int],
  session_context: dict[str, Any] | None = None,
) -> CoachingFeedback:
  increment("ai_feedback_requests_total")
  start = perf_counter()
  fallback_reason = "ollama_disabled"
  model_failures: list[str] = []

  system_prompt, user_prompt, resolved_prompt_version = resolve_feedback_prompts(
    prompt_version=settings.prompt_version,
    session_id=session_id,
    exercise_type=exercise_type,
    overall_score=overall_score,
    metric_summary=metric_summary,
    session_context=session_context,
  )
  prompt_metric_suffix = _metric_name_for_prompt_version(resolved_prompt_version)

  if settings.openrouter_enabled and settings.openrouter_api_key:
    try:
      client = OpenRouterClient(
        api_key=settings.openrouter_api_key,
        model=settings.openrouter_model,
        timeout_s=settings.openrouter_timeout_s,
        temperature=settings.openrouter_temperature,
      )
      payload, model_latency_ms = client.generate_json(system_prompt=system_prompt, user_prompt=user_prompt)
      feedback = _coerce_feedback_payload(
        payload=payload,
        session_id=session_id,
        overall_score=overall_score,
        model_used=f"openrouter:{client.model}",
        prompt_version=resolved_prompt_version,
        latency_ms=model_latency_ms,
      )
      increment("ai_feedback_success_total")
      increment(f"ai_feedback_success_prompt_{prompt_metric_suffix}_total")
      increment(f"ai_model_usage_openrouter_{_metric_name_for_model(client.model)}")
      observe("ai_feedback_latency_ms", model_latency_ms)
      return feedback
    except ValidationError as exc:
      logger.warning("openrouter_feedback_validation_failed session_id=%s error=%s", session_id, exc)
      increment("ai_feedback_validation_failure_total")
      model_failures.append(f"openrouter:{settings.openrouter_model}:validation")
    except Exception as exc:
      logger.warning("openrouter_feedback_failed session_id=%s error=%s", session_id, exc)
      increment("ai_feedback_model_failure_total")
      failure_reason = _classify_model_exception(exc)
      model_failures.append(f"openrouter:{settings.openrouter_model}:{failure_reason}")
      increment(f"ai_feedback_model_failure_reason_{_metric_name_for_reason(failure_reason)}_total")
    fallback_reason = "openrouter_failed"

  if settings.ollama_enabled:
    model_router = OllamaModelRouter(settings.ollama_models)
    candidates = model_router.candidates()
    if not candidates:
      fallback_reason = "no_models_configured"
    for model_name in candidates:
      try:
        client = OllamaClient(
          base_url=settings.ollama_base_url,
          model=model_name,
          timeout_s=settings.ollama_timeout_s,
          temperature=settings.ollama_temperature,
        )
        payload, model_latency_ms = client.generate_json(system_prompt=system_prompt, user_prompt=user_prompt)
        feedback = _coerce_feedback_payload(
          payload=payload,
          session_id=session_id,
          overall_score=overall_score,
          model_used=client.model,
          prompt_version=resolved_prompt_version,
          latency_ms=model_latency_ms,
        )
        increment("ai_feedback_success_total")
        increment(f"ai_feedback_success_prompt_{prompt_metric_suffix}_total")
        increment(f"ai_model_usage_{_metric_name_for_model(client.model)}")
        observe("ai_feedback_latency_ms", model_latency_ms)
        return feedback
      except ValidationError as exc:
        logger.warning("ollama_feedback_validation_failed session_id=%s model=%s error=%s", session_id, model_name, exc)
        increment("ai_feedback_validation_failure_total")
      except Exception as exc:
        logger.warning("ollama_feedback_model_failed session_id=%s model=%s error=%s", session_id, model_name, exc)
        increment("ai_feedback_model_failure_total")
        failure_reason = _classify_model_exception(exc)
        model_failures.append(f"{model_name}:{failure_reason}")
        increment(f"ai_feedback_model_failure_reason_{_metric_name_for_reason(failure_reason)}_total")

    increment("ai_feedback_failure_total")
    increment(f"ai_feedback_failure_prompt_{prompt_metric_suffix}_total")
    if candidates:
      fallback_reason = "all_models_failed"

  fallback_latency_ms = int((perf_counter() - start) * 1000)
  feedback = _fallback_feedback(
    session_id=session_id,
    overall_score=overall_score,
    exercise_type=exercise_type,
    prompt_version=resolved_prompt_version,
    latency_ms=fallback_latency_ms,
  )
  increment("ai_feedback_fallback_total")
  increment(f"ai_feedback_fallback_prompt_{prompt_metric_suffix}_total")
  increment(f"ai_feedback_fallback_reason_{_metric_name_for_reason(fallback_reason)}_total")
  observe("ai_feedback_latency_ms", fallback_latency_ms)
  logger.warning(
    "ollama_feedback_fallback_used session_id=%s reason=%s model_failures=%s",
    session_id,
    fallback_reason,
    ",".join(model_failures) if model_failures else "none",
  )
  return feedback
