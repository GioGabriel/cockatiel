from types import SimpleNamespace


def test_feedback_orchestrator_uses_google_ai_only_for_the_summary(monkeypatch):
  from app.ai_engine.orchestrator import service

  class FakeGoogleClient:
    model = "gemini-test-model"

    def __init__(self, **kwargs):
      assert kwargs["api_keys"] == ["first-key", "second-key"]
      assert kwargs["model"] == "gemini-test-model"

    def generate_json(self, *, system_prompt: str, user_prompt: str):
      assert system_prompt
      assert user_prompt
      return {"summary": "Your pitch stayed connected."}, 12

  monkeypatch.setattr(
    service,
    "settings",
    SimpleNamespace(
      google_ai_enabled=True,
      google_api_keys=["first-key", "second-key"],
      google_ai_model="gemini-test-model",
      google_ai_timeout_s=5,
      google_ai_temperature=0.2,
      google_ai_max_output_tokens=256,
      google_ai_fallback_models=[],
      google_ai_max_total_time_s=5,
      prompt_version="v1",
    ),
  )
  monkeypatch.setattr(service, "GoogleAiStudioClient", FakeGoogleClient)

  feedback = service.generate_feedback(
    session_id="session-1",
    overall_score=82,
    exercise_type="warmup_pitch",
    metric_summary={
      "metric_mode": "voice",
      "sample_count": 64,
      "pitch_accuracy": 86,
      "timing_accuracy": 78,
      "breath_control": 80,
      "pitch_stability": 84,
      "vibrato_consistency": 70,
      "note_transition_smoothness": 76,
    },
  )

  assert feedback.summary == "Your pitch stayed connected."
  assert feedback.model_used == "google-ai-studio:gemini-test-model"
  assert feedback.overall_score == 82
