from types import SimpleNamespace


def test_feedback_orchestrator_uses_google_ai_for_evidence_backed_detail(monkeypatch):
  from app.ai_engine.orchestrator import service

  class FakeGoogleClient:
    model = "gemini-test-model"

    def __init__(self, **kwargs):
      assert kwargs["api_keys"] == ["first-key", "second-key"]
      assert kwargs["model"] == "gemini-test-model"

    def generate_json(self, *, system_prompt: str, user_prompt: str):
      assert system_prompt
      assert user_prompt
      assert "pitch_accuracy" in user_prompt
      assert "evidence_quality" in user_prompt
      assert "not_measurable" in user_prompt
      return {
        "summary": "Your target-note guide was not available for this take, so pitch matching could not be judged fairly.",
        "detailed_improvements": [
          {
            "metric_key": "pitch_accuracy",
            "priority": "high",
            "finding": "Pitch accuracy was not measurable in this take.",
            "evidence": "0 target-note comparison frames were captured.",
            "why_it_matters": "Without a target, the app cannot tell whether the note was matched.",
            "action": "Start the guided note and sing after the target appears.",
            "practice_plan": "Repeat one target note for 10 seconds with the guide visible.",
          },
        ],
      }, 12

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
    score_breakdown={
      "metric_mode": "voice",
      "focus_metrics": ["pitch_accuracy", "timing_accuracy"],
      "metric_scores": {"pitch_accuracy": 86, "timing_accuracy": 78},
      "weighted_components": {"pitch_accuracy": 25.8, "timing_accuracy": 15.6},
      "scoring_version": "2.0",
      "sample_count": 128,
      "evidence_quality": "reliable",
      "recording_evidence": {"target_coverage_pct": 0},
      "metric_details": {
        "pitch_accuracy": {
          "status": "not_measurable",
          "reason": "No target-note comparison frames were captured.",
        },
      },
      "segments": [],
    },
  )

  assert feedback.summary == "Your target-note guide was not available for this take, so pitch matching could not be judged fairly."
  assert feedback.model_used == "google-ai-studio:gemini-test-model"
  assert feedback.overall_score == 82
  assert feedback.score_breakdown is not None
  assert feedback.score_breakdown["metric_scores"]["pitch_accuracy"] == 86
  assert feedback.score_breakdown["evidence_quality"] == "reliable"
  assert feedback.detailed_improvements[0].metric_key == "pitch_accuracy"
