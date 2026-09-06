from app.modules.training.scoring import score_training_attempt


def test_score_breakdown_reports_scoring_version_and_evidence_quality():
  result = score_training_attempt(
    exercise_id="warmup_pitch",
    metric_summary={
      "sample_count": 6,
      "pitch_accuracy": 80,
      "timing_accuracy": 80,
      "breath_control": 80,
      "pitch_stability": 80,
      "vibrato_consistency": 80,
      "note_transition_smoothness": 80,
    },
  )

  assert result["score_breakdown"]["scoring_version"] == "2.0"
  assert result["score_breakdown"]["evidence_quality"] == "insufficient"
  assert result["score_breakdown"]["sample_count"] == 6


def test_score_breakdown_marks_longer_observations_as_reliable():
  result = score_training_attempt(
    exercise_id="warmup_pitch",
    metric_summary={
      "sample_count": 160,
      "pitch_accuracy": 80,
      "timing_accuracy": 80,
      "breath_control": 80,
      "pitch_stability": 80,
      "vibrato_consistency": 80,
      "note_transition_smoothness": 80,
    },
  )

  assert result["score_breakdown"]["evidence_quality"] == "reliable"
