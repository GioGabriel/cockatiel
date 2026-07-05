from types import SimpleNamespace
from typing import cast

from app.ai_engine.orchestrator import service as orchestrator
from app.observability.metrics.registry import reset as reset_metrics
from app.observability.metrics.registry import snapshot


def _settings(**overrides):
  base = {
    "prompt_version": "v1",
    "ollama_enabled": False,
    "ollama_base_url": "http://localhost:11434",
    "ollama_model": "llama3.1:8b",
    "ollama_models": ("llama3.1:8b",),
    "ollama_timeout_s": 10,
    "ollama_temperature": 0.2,
    "openrouter_enabled": False,
    "openrouter_api_key": "",
    "openrouter_model": "",
    "openrouter_timeout_s": 30,
    "openrouter_temperature": 0.2,
  }
  base.update(overrides)
  return SimpleNamespace(**base)


def _counters() -> dict[str, int]:
  return cast(dict[str, int], snapshot()["counters"])


def test_generate_feedback_uses_fallback_when_ollama_disabled(monkeypatch):
  reset_metrics()
  monkeypatch.setattr(orchestrator, "settings", _settings(ollama_enabled=False, prompt_version="v1a"))

  feedback = orchestrator.generate_feedback(
    session_id="session-1",
    overall_score=74.3,
    exercise_type="warmup_pitch",
    metric_summary={"pitch_accuracy": 74.3},
  )

  assert feedback.model_used == "fallback-rules"
  assert feedback.prompt_version == "v1a"
  counters = _counters()
  assert counters.get("ai_feedback_fallback_total") == 1
  assert counters.get("ai_feedback_fallback_prompt_v1a_total") == 1
  assert counters.get("ai_feedback_fallback_reason_ollama_disabled_total") == 1


def test_generate_feedback_retries_next_model_on_validation_error(monkeypatch):
  reset_metrics()
  monkeypatch.setattr(
    orchestrator,
    "settings",
    _settings(ollama_enabled=True, ollama_models=("bad-model", "good-model"), prompt_version="v1b"),
  )

  class FakeClient:
    def __init__(self, *, model: str, **kwargs):
      self.model = model

    def generate_json(self, *, system_prompt: str, user_prompt: str):
      if self.model == "bad-model":
        return {"strengths": ["A"], "improvements": ["B"]}, 9
      return {
        "strengths": ["Pitch center is improving"],
        "improvements": ["Support breath at phrase endings"],
        "next_exercises": ["Sustain-and-release drill"],
      }, 11

  monkeypatch.setattr(orchestrator, "OllamaClient", FakeClient)

  feedback = orchestrator.generate_feedback(
    session_id="session-2",
    overall_score=81.1,
    exercise_type="karaoke",
    metric_summary={"timing_accuracy": 80.5},
  )

  assert feedback.model_used == "good-model"
  assert feedback.prompt_version == "v1b"
  counters = _counters()
  assert counters.get("ai_feedback_validation_failure_total") == 1
  assert counters.get("ai_feedback_success_total") == 1
  assert counters.get("ai_feedback_success_prompt_v1b_total") == 1


def test_generate_feedback_falls_back_when_all_models_fail(monkeypatch):
  reset_metrics()
  monkeypatch.setattr(
    orchestrator,
    "settings",
    _settings(ollama_enabled=True, ollama_models=("m1", "m2"), prompt_version="v1b"),
  )

  class FakeClient:
    def __init__(self, *, model: str, **kwargs):
      self.model = model

    def generate_json(self, *, system_prompt: str, user_prompt: str):
      return {"strengths": [], "improvements": [], "next_exercises": []}, 7

  monkeypatch.setattr(orchestrator, "OllamaClient", FakeClient)

  feedback = orchestrator.generate_feedback(
    session_id="session-3",
    overall_score=66.0,
    exercise_type="warmup_pitch",
    metric_summary={"pitch_accuracy": 66.0},
  )

  assert feedback.model_used == "fallback-rules"
  assert feedback.prompt_version == "v1b"
  counters = _counters()
  assert counters.get("ai_feedback_validation_failure_total") == 2
  assert counters.get("ai_feedback_failure_total") == 1
  assert counters.get("ai_feedback_failure_prompt_v1b_total") == 1
  assert counters.get("ai_feedback_fallback_total") == 1
  assert counters.get("ai_feedback_fallback_prompt_v1b_total") == 1
  assert counters.get("ai_feedback_fallback_reason_all_models_failed_total") == 1


def test_generate_feedback_tracks_timeout_failures(monkeypatch):
  reset_metrics()
  monkeypatch.setattr(
    orchestrator,
    "settings",
    _settings(ollama_enabled=True, ollama_models=("slow-model",), prompt_version="v1"),
  )

  class FakeClient:
    def __init__(self, *, model: str, **kwargs):
      self.model = model

    def generate_json(self, *, system_prompt: str, user_prompt: str):
      raise TimeoutError("timed out")

  monkeypatch.setattr(orchestrator, "OllamaClient", FakeClient)

  feedback = orchestrator.generate_feedback(
    session_id="session-timeout",
    overall_score=70.0,
    exercise_type="warmup_pitch",
    metric_summary={"pitch_accuracy": 70.0},
  )

  assert feedback.model_used == "fallback-rules"
  counters = _counters()
  assert counters.get("ai_feedback_model_failure_total") == 1
  assert counters.get("ai_feedback_model_failure_reason_timeout_total") == 1
  assert counters.get("ai_feedback_fallback_reason_all_models_failed_total") == 1
