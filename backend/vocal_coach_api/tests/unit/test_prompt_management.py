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
    },
  )

  assert "7/100" in prompt
  assert "pitch_accuracy" in prompt
  assert "reliable" in prompt
  assert "180" in prompt
