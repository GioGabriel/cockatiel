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

  assert result["score_breakdown"]["scoring_version"] == "2.2"
  assert result["score_breakdown"]["evidence_quality"] == "insufficient"
  assert result["score_breakdown"]["score_status"] == "insufficient_evidence"
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


def test_score_breakdown_explains_zero_metrics_without_target_evidence():
  result = score_training_attempt(
    exercise_id="warmup_pitch",
    metric_summary={
      "sample_count": 706,
      "pitch_accuracy": 0,
      "timing_accuracy": 0,
      "breath_control": 48,
      "pitch_stability": 1,
      "vibrato_consistency": 47,
      "note_transition_smoothness": 0,
      "evidence": {
        "duration_ms": 22400,
        "frame_count": 706,
        "voiced_frame_count": 352,
        "target_window_frame_count": 0,
        "target_frame_count": 0,
        "low_confidence_frame_count": 12,
        "no_target_frame_count": 706,
        "dropped_frame_count": 0,
        "stream_gap_count": 0,
        "voiced_coverage_pct": 49.86,
        "target_window_coverage_pct": 0,
        "target_coverage_pct": 0,
        "on_target_rate_pct": 0,
        "mean_confidence": 0.81,
        "confidence_stddev": 0.08,
        "mean_loudness_db": -24.0,
        "loudness_stddev_db": 3.2,
        "mean_abs_cents": 0,
        "p95_abs_cents": 0,
        "pitch_bias_cents": 0,
        "pitch_stddev_cents": 0,
        "longest_voiced_run_ms": 960,
        "voiced_run_count": 4,
        "interruption_count": 3,
        "transition_count": 0,
        "completed_transition_count": 0,
        "failed_transition_count": 0,
        "vibrato_detected": False,
        "vibrato_rate_hz": None,
        "vibrato_amplitude_cents": None,
        "vibrato_regularity_pct": None,
        "segments": [],
      },
    },
  )

  breakdown = result["score_breakdown"]
  assert breakdown["recording_evidence"]["target_coverage_pct"] == 0
  assert breakdown["metric_details"]["pitch_accuracy"]["status"] == "not_measurable"
  assert "target-note" in breakdown["metric_details"]["pitch_accuracy"]["reason"]
  assert breakdown["metric_details"]["timing_accuracy"]["status"] == "not_measurable"
  assert breakdown["metric_details"]["breath_control"]["status"] == "partial"
  assert breakdown["score_status"] == "not_scorable"
  assert breakdown["score_reliability"] == "not_scorable"


def test_legacy_score_is_marked_without_rewriting_old_numeric_results():
  result = score_training_attempt(
    exercise_id="warmup_pitch",
    metric_summary={
      "sample_count": 180,
      "pitch_accuracy": 72,
      "timing_accuracy": 68,
      "breath_control": 80,
      "pitch_stability": 74,
      "vibrato_consistency": 70,
      "note_transition_smoothness": 65,
    },
  )

  assert result["overall_score"] > 0
  assert result["score_breakdown"]["score_status"] == "legacy"
  assert result["score_breakdown"]["legacy_evidence"] is True


def test_score_breakdown_keeps_segment_evidence_for_location_specific_feedback():
  result = score_training_attempt(
    exercise_id="warmup_pitch",
    metric_summary={
      "sample_count": 128,
      "pitch_accuracy": 72,
      "timing_accuracy": 68,
      "breath_control": 80,
      "pitch_stability": 74,
      "vibrato_consistency": 70,
      "note_transition_smoothness": 65,
      "evidence": {
        "frame_count": 128,
        "voiced_frame_count": 120,
        "target_window_frame_count": 128,
        "target_frame_count": 120,
        "no_target_frame_count": 0,
        "segments": [
          {
            "segment_id": "stage_2",
            "label": "Mi",
            "target_frequency_hz": 329.63,
            "start_ms": 4000,
            "end_ms": 8000,
            "frame_count": 64,
            "voiced_frame_count": 56,
            "target_frame_count": 56,
            "voiced_coverage_pct": 87.5,
            "target_coverage_pct": 87.5,
            "on_target_rate_pct": 42.0,
            "mean_confidence": 0.77,
            "mean_abs_cents": 81.0,
            "p95_abs_cents": 124.0,
            "pitch_stddev_cents": 18.0,
            "score": 39.0,
            "status": "measured",
            "reason": "Most confident frames were more than 50 cents from the target.",
          },
        ],
      },
    },
  )

  segment = result["score_breakdown"]["segments"][0]
  assert segment["label"] == "Mi"
  assert segment["target_frequency_hz"] == 329.63
  assert segment["pitch_stddev_cents"] == 18.0
  assert segment["score"] == 39.0
  assert result["score_breakdown"]["metric_details"]["pitch_accuracy"]["status"] == "measured"


def test_breathing_score_breakdown_explains_phase_evidence():
  result = score_training_attempt(
    exercise_id="breath_support_ladder",
    metric_summary={
      "metric_mode": "breathing",
      "sample_count": 30,
      "phase_completion_rate": 75,
      "pace_adherence": 64,
      "cycle_consistency": 70,
      "completion_rate": 82,
      "interruption_count": 1,
      "evidence": {
        "duration_ms": 30000,
        "phase_count": 4,
        "completed_phase_count": 3,
        "interruption_count": 1,
      },
    },
  )

  breakdown = result["score_breakdown"]
  assert breakdown["recording_evidence"]["phase_count"] == 4
  assert breakdown["recording_evidence"]["completed_phase_count"] == 3
  assert breakdown["metric_details"]["phase_completion_rate"]["status"] == "partial"
  assert "3 of 4" in breakdown["metric_details"]["phase_completion_rate"]["reason"]
