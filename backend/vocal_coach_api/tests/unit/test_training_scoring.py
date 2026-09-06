import math

from app.modules.training.scoring import score_training_attempt


def test_resonance_placement_scoring_uses_focus_weights_and_thresholds():
  result = score_training_attempt(
    exercise_id="resonance_placement",
    metric_summary={
      "sample_count": 64,
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
      "sample_count": 64,
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
      "sample_count": 64,
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


def test_scoring_clamps_non_finite_and_out_of_range_metric_values():
  result = score_training_attempt(
    exercise_id="do_re_mi_basic_ladder",
    metric_summary={
      "pitch_accuracy": math.inf,
      "timing_accuracy": -25,
      "breath_control": 150,
      "pitch_stability": math.nan,
      "vibrato_consistency": 80,
      "note_transition_smoothness": "not-a-score",
    },
  )

  assert result["score_breakdown"]["metric_scores"] == {
    "pitch_accuracy": 0.0,
    "timing_accuracy": 0.0,
    "breath_control": 100.0,
    "pitch_stability": 0.0,
    "vibrato_consistency": 80.0,
    "note_transition_smoothness": 0.0,
  }
  assert 0 <= result["overall_score"] <= 100


def test_scoring_uses_only_valid_focus_metrics_when_catalog_is_incomplete():
  result = score_training_attempt(
    exercise_id="unknown-exercise",
    metric_summary={
      "pitch_accuracy": 90,
      "timing_accuracy": 80,
      "breath_control": 70,
      "pitch_stability": 60,
      "vibrato_consistency": 50,
      "note_transition_smoothness": 40,
    },
  )

  assert result["score_breakdown"]["focus_metrics"] == [
    "pitch_accuracy",
    "timing_accuracy",
    "breath_control",
  ]
  assert result["strongest_metric"] == "pitch_accuracy"
