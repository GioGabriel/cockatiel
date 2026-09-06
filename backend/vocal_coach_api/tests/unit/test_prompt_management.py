def test_feedback_prompt_includes_evidence_for_user_facing_coaching():
  from app.ai_engine.prompt_management.templates.v1 import render_user_prompt

  prompt = render_user_prompt(
    overall_score=7,
    exercise_type="warmup_pitch",
    strengths=["You completed a practice attempt"],
    improvements=["Several notes drifted above or below the target"],
    score_breakdown={
      "metric_scores": {"pitch_accuracy": 7},
      "weighted_components": {"pitch_accuracy": 2.1},
      "evidence_quality": "reliable",
      "sample_count": 180,
      "focus_metrics": ["pitch_accuracy"],
      "recording_evidence": {
        "voiced_coverage_pct": 49.86,
        "target_coverage_pct": 0,
        "no_target_frame_count": 180,
      },
      "metric_details": {
        "pitch_accuracy": {
          "status": "not_measurable",
          "reason": "No target-note comparison frames were captured.",
        },
      },
      "segments": [],
    },
  )

  assert "7/100" in prompt
  assert "pitch_accuracy" in prompt
  assert "reliable" in prompt
  assert "180" in prompt
  assert "not_measurable" in prompt
  assert "No target-note comparison" in prompt
