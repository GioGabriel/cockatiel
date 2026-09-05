from app.ai_engine.orchestrator.coaching_engine import CoachingLogicEngine


def test_voice_feedback_covers_mid_range_metrics_with_specific_next_steps():
  strengths, improvements, next_exercises = CoachingLogicEngine.evaluate(
    overall_score=76,
    exercise_type="warmup_pitch",
    metric_summary={
      "pitch_accuracy": 76,
      "timing_accuracy": 74,
      "breath_control": 78,
      "pitch_stability": 72,
      "vibrato_consistency": 65,
      "note_transition_smoothness": 68,
    },
  )

  assert strengths
  assert improvements
  assert next_exercises
  assert any("pitch" in item.lower() for item in improvements)
  assert any("drill" in item.lower() or "practice" in item.lower() for item in next_exercises)


def test_feedback_does_not_praise_an_empty_or_invalid_recording():
  strengths, improvements, next_exercises = CoachingLogicEngine.evaluate(
    overall_score=0,
    exercise_type="warmup_pitch",
    metric_summary={
      "sample_count": 0,
      "pitch_accuracy": None,
      "timing_accuracy": "invalid",
      "breath_control": float("nan"),
    },
  )

  assert not any("very consistent" in item.lower() for item in strengths)
  assert improvements
  assert next_exercises
  assert any("microphone" in item.lower() or "data" in item.lower() for item in improvements)


def test_breathing_feedback_handles_interrupted_cycles():
  strengths, improvements, next_exercises = CoachingLogicEngine.evaluate(
    overall_score=68,
    exercise_type="breath_support_ladder",
    metric_summary={
      "metric_mode": "breathing",
      "phase_completion_rate": 70,
      "pace_adherence": 68,
      "cycle_consistency": 65,
      "completion_rate": 70,
      "interruption_count": 3,
    },
  )

  assert improvements
  assert next_exercises
  assert any("interruption" in item.lower() for item in improvements)
