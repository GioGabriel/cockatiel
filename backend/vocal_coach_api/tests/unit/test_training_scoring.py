from app.modules.training.scoring import score_training_attempt


def test_resonance_placement_scoring_uses_focus_weights_and_thresholds():
  result = score_training_attempt(
    exercise_id="resonance_placement",
    metric_summary={
      "sample_count": 6,
      "pitch_accuracy": 74,
      "timing_accuracy": 68,
      "breath_control": 88,
      "pitch_stability": 79,
      "vibrato_consistency": 60,
      "note_transition_smoothness": 66,
    },
  )

  assert result["overall_score"] == 77.35
  assert result["strongest_metric"] == "breath_control"
  assert result["weakest_metric"] == "pitch_accuracy"
  assert result["passed_threshold"] is True


def test_note_transition_drill_prioritizes_transition_metric():
  result = score_training_attempt(
    exercise_id="note_transition_drill",
    metric_summary={
      "sample_count": 6,
      "pitch_accuracy": 78,
      "timing_accuracy": 72,
      "breath_control": 70,
      "pitch_stability": 74,
      "vibrato_consistency": 64,
      "note_transition_smoothness": 60,
    },
  )

  assert result["strongest_metric"] == "pitch_stability"
  assert result["weakest_metric"] == "note_transition_smoothness"
  assert result["passed_threshold"] is False


def test_breath_support_ladder_prioritizes_breath_control():
  result = score_training_attempt(
    exercise_id="breath_support_ladder",
    metric_summary={
      "sample_count": 6,
      "phase_completion_rate": 92,
      "pace_adherence": 88,
      "cycle_consistency": 84,
      "completion_rate": 100,
    },
  )

  assert result["overall_score"] == 90.4
  assert result["score_breakdown"]["metric_mode"] == "breathing"
  assert result["strongest_metric"] == "phase_completion_rate"
  assert result["weakest_metric"] == "cycle_consistency"
  assert result["passed_threshold"] is True
