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


def test_fallback_summary_explains_the_score_and_lowest_measured_area():
  summary = CoachingLogicEngine.generate_fallback_summary(
    overall_score=7,
    exercise_type="warmup_pitch",
    metric_summary={
      "metric_mode": "voice",
      "sample_count": 180,
      "pitch_accuracy": 7,
      "timing_accuracy": 19,
      "breath_control": 24,
      "pitch_stability": 18,
      "vibrato_consistency": 12,
      "note_transition_smoothness": 15,
    },
    strengths=["Your practice has a clear baseline"],
    improvements=["Several notes drifted above or below the target"],
  )

  assert "7/100" in summary
  assert "pitch accuracy" in summary.lower()
  assert "7/100" in summary.lower().split("pitch accuracy", 1)[1]


def test_detailed_improvements_reference_the_measured_reason_and_action():
  score_breakdown = {
    "metric_mode": "voice",
    "metric_scores": {
      "pitch_accuracy": 0,
      "timing_accuracy": 0,
      "breath_control": 48,
      "pitch_stability": 1,
      "vibrato_consistency": 47,
      "note_transition_smoothness": 0,
    },
    "metric_details": {
      "pitch_accuracy": {
        "status": "not_measurable",
        "reason": "No target-note comparison frames were captured, so pitch accuracy cannot be judged from this take.",
        "observed_frames": 0,
        "coverage_pct": 0,
      },
      "breath_control": {
        "status": "measured",
        "reason": "Voice was present in about half of the captured frames.",
        "observed_frames": 352,
        "coverage_pct": 49.86,
      },
    },
    "recording_evidence": {
      "frame_count": 706,
      "voiced_frame_count": 352,
      "target_frame_count": 0,
      "target_coverage_pct": 0,
      "voiced_coverage_pct": 49.86,
    },
  }

  improvements = CoachingLogicEngine.build_detailed_improvements(
    exercise_type="warmup_pitch",
    metric_summary={
      "metric_mode": "voice",
      "sample_count": 706,
      "pitch_accuracy": 0,
      "timing_accuracy": 0,
      "breath_control": 48,
      "pitch_stability": 1,
      "vibrato_consistency": 47,
      "note_transition_smoothness": 0,
    },
    score_breakdown=score_breakdown,
  )

  assert improvements
  assert improvements[0]["metric_key"] == "pitch_accuracy"
  assert "target-note" in improvements[0]["evidence"]
  assert improvements[0]["action"]
  assert improvements[0]["practice_plan"]
