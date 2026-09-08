import math
from typing import Any

from app.modules.training.catalog import default_metric_weights, get_exercise

VOICE_METRIC_FIELDS = (
  "pitch_accuracy",
  "timing_accuracy",
  "breath_control",
  "pitch_stability",
  "vibrato_consistency",
  "note_transition_smoothness",
)

BREATHING_METRIC_FIELDS = (
  "phase_completion_rate",
  "pace_adherence",
  "cycle_consistency",
  "completion_rate",
)

SCORING_VERSION = "2.2"
MIN_EVIDENCE_SAMPLES = 16
RELIABLE_EVIDENCE_SAMPLES = 128

_TARGET_COMPARISON_METRICS = {
  "pitch_accuracy",
  "timing_accuracy",
  "pitch_stability",
  "vibrato_consistency",
  "note_transition_smoothness",
}

_METRIC_DETAIL_ACTIONS = {
  "pitch_accuracy": "Match one target note at a time with the guide, then repeat the phrase slowly.",
  "timing_accuracy": "Wait for the target window, count the beat, and repeat the same phrase without rushing.",
  "breath_control": "Take a relaxed breath before the phrase and keep the recorded voice signal comfortably continuous until it ends.",
  "pitch_stability": "Hold a comfortable note for a few seconds and keep the sound even instead of pushing for volume.",
  "vibrato_consistency": "Make the sustained note steady first, then add a gentle, natural vibrato.",
  "note_transition_smoothness": "Slow the two-note change down and connect the next target without sliding past it.",
  "phase_completion_rate": "Follow every inhale, hold, and exhale to the final count before starting the next phase.",
  "pace_adherence": "Let the guide set the speed and keep each inhale or exhale relaxed rather than rushed.",
  "cycle_consistency": "Repeat the same breathing pattern at a comfortable pace so each cycle feels similar.",
  "completion_rate": "Use a shorter routine first, then complete the full sequence one calm phase at a time.",
}


def metric_mode_for_exercise(exercise_id: str) -> str:
  exercise = get_exercise(exercise_id) or {}
  exercise_mode = str(exercise.get("exercise_mode") or "voice").strip().lower()
  return "breathing" if exercise_mode == "breathing_timer" else "voice"


def metric_fields_for_exercise(exercise_id: str) -> tuple[str, ...]:
  return BREATHING_METRIC_FIELDS if metric_mode_for_exercise(exercise_id) == "breathing" else VOICE_METRIC_FIELDS


def _default_breathing_metric_weights() -> dict[str, float]:
  return {
    "phase_completion_rate": 0.35,
    "pace_adherence": 0.3,
    "cycle_consistency": 0.2,
    "completion_rate": 0.15,
  }


def _safe_float(value: Any, default: float = 0.0) -> float:
  try:
    parsed = float(value)
  except (TypeError, ValueError):
    return default
  return parsed if math.isfinite(parsed) else default


def _normalized_metric_weights(exercise_id: str, metric_fields: tuple[str, ...]) -> dict[str, float]:
  exercise = get_exercise(exercise_id) or {}
  weights = dict(exercise.get("metric_weights") or default_metric_weights())
  total = sum(max(_safe_float(weights.get(field)), 0.0) for field in metric_fields)
  if total <= 0:
    fallback = (
      _default_breathing_metric_weights()
      if metric_mode_for_exercise(exercise_id) == "breathing"
      else default_metric_weights()
    )
    total = sum(float(fallback[field]) for field in metric_fields)
    weights = fallback
  return {
    field: round(max(_safe_float(weights.get(field)), 0.0) / total, 4)
    for field in metric_fields
  }


def _metric_value(metric_summary: dict[str, Any], field: str) -> float:
  return round(min(max(_safe_float(metric_summary.get(field)), 0.0), 100.0), 2)


def _evidence_quality(metric_summary: dict[str, Any]) -> str:
  sample_count = max(0, int(_safe_float(metric_summary.get("sample_count"), 0.0)))
  if sample_count < MIN_EVIDENCE_SAMPLES:
    return "insufficient"
  if sample_count < RELIABLE_EVIDENCE_SAMPLES:
    return "limited"
  return "reliable"


def _score_status(
  *,
  metric_mode: str,
  evidence_quality: str,
  evidence: dict[str, Any],
  has_detailed_evidence: bool,
) -> str:
  """Classify whether a numeric result is safe to present as a score.

  Numeric components remain in the response for backward compatibility, but
  this status is authoritative for presentation and coaching language. A
  zero target comparison is missing evidence, not evidence of poor singing.
  """

  if evidence_quality == "insufficient":
    return "insufficient_evidence"
  if metric_mode == "breathing":
    if has_detailed_evidence and _safe_int(evidence.get("phase_count")) <= 0:
      return "not_scorable"
    if has_detailed_evidence and _safe_float(evidence.get("phase_coverage_pct")) < 80:
      return "partial"
    return "measured" if has_detailed_evidence else "legacy"

  target_count = _safe_int(evidence.get("target_frame_count"))
  frame_count = _safe_int(evidence.get("frame_count"))
  if has_detailed_evidence and target_count <= 0:
    return "not_scorable"
  if has_detailed_evidence and target_count < MIN_EVIDENCE_SAMPLES:
    return "insufficient_evidence"
  if not has_detailed_evidence:
    return "legacy"
  if (
    _safe_float(evidence.get("target_coverage_pct")) < 80
    or _safe_int(evidence.get("stream_gap_count")) > 0
    or frame_count < RELIABLE_EVIDENCE_SAMPLES
  ):
    return "partial"
  return "measured"


def _safe_int(value: Any, default: int = 0) -> int:
  try:
    return max(int(value), 0)
  except (TypeError, ValueError):
    return default


def _raw_evidence(metric_summary: dict[str, Any]) -> dict[str, Any] | None:
  raw = metric_summary.get("evidence")
  if raw is None:
    return None
  if hasattr(raw, "model_dump"):
    raw = raw.model_dump()
  return dict(raw) if isinstance(raw, dict) else None


def _normalized_recording_evidence(
  metric_summary: dict[str, Any],
) -> tuple[dict[str, Any], bool]:
  raw = _raw_evidence(metric_summary)
  sample_count = _safe_int(metric_summary.get("sample_count"))
  if raw is None:
    # Older clients only sent the six scores. Treat those scores as measured
    # evidence for compatibility, while new clients send the full report.
    return {
      "duration_ms": max(
        0,
        _safe_int(metric_summary.get("last_timestamp_ms"))
        - _safe_int(metric_summary.get("first_timestamp_ms")),
      ),
      "frame_count": sample_count,
      "voiced_frame_count": sample_count,
      "target_window_frame_count": sample_count,
      "target_frame_count": sample_count,
      "low_confidence_frame_count": 0,
      "no_target_frame_count": 0,
      "dropped_frame_count": 0,
      "stream_gap_count": 0,
      "voiced_coverage_pct": 100.0 if sample_count else 0.0,
      "target_window_coverage_pct": 100.0 if sample_count else 0.0,
      "target_coverage_pct": 100.0 if sample_count else 0.0,
      "on_target_rate_pct": _metric_value(metric_summary, "timing_accuracy"),
      "mean_confidence": 1.0 if sample_count else 0.0,
      "confidence_stddev": 0.0,
      "mean_loudness_db": None,
      "loudness_stddev_db": None,
      "mean_abs_cents": 0.0,
      "p95_abs_cents": 0.0,
      "pitch_bias_cents": 0.0,
      "pitch_stddev_cents": 0.0,
      "mean_onset_delay_ms": 0.0,
      "p95_onset_delay_ms": 0.0,
      "late_onset_count": 0,
      "mean_settling_time_ms": 0.0,
      "mean_zero_crossing_rate": None,
      "mean_spectral_centroid_hz": None,
      "mean_spectral_rolloff_hz": None,
      "mean_crest_factor_db": None,
      "clipping_ratio_pct": None,
      "mean_periodicity": None,
      "longest_voiced_run_ms": 0,
      "voiced_run_count": 1 if sample_count else 0,
      "interruption_count": 0,
      "transition_count": 0,
      "completed_transition_count": 0,
      "failed_transition_count": 0,
      "vibrato_detected": False,
      "vibrato_rate_hz": None,
      "vibrato_amplitude_cents": None,
      "vibrato_regularity_pct": None,
      "segments": [],
    }, False

  frame_count = _safe_int(raw.get("frame_count"), sample_count)
  voiced_frame_count = _safe_int(raw.get("voiced_frame_count"))
  target_window_frame_count = _safe_int(raw.get("target_window_frame_count"))
  target_frame_count = _safe_int(raw.get("target_frame_count"))
  voiced_coverage_pct = (
    _metric_value(raw, "voiced_coverage_pct")
    if raw.get("voiced_coverage_pct") is not None
    else round((voiced_frame_count / frame_count * 100) if frame_count else 0.0, 2)
  )
  target_window_coverage_pct = (
    _metric_value(raw, "target_window_coverage_pct")
    if raw.get("target_window_coverage_pct") is not None
    else round((target_window_frame_count / frame_count * 100) if frame_count else 0.0, 2)
  )
  target_coverage_pct = (
    _metric_value(raw, "target_coverage_pct")
    if raw.get("target_coverage_pct") is not None
    else round((target_frame_count / frame_count * 100) if frame_count else 0.0, 2)
  )
  return {
    "duration_ms": _safe_int(raw.get("duration_ms")),
    "frame_count": frame_count,
    "voiced_frame_count": voiced_frame_count,
    "target_window_frame_count": target_window_frame_count,
    "target_frame_count": target_frame_count,
    "low_confidence_frame_count": _safe_int(raw.get("low_confidence_frame_count")),
    "no_target_frame_count": _safe_int(raw.get("no_target_frame_count")),
    "dropped_frame_count": _safe_int(raw.get("dropped_frame_count")),
    "stream_gap_count": _safe_int(raw.get("stream_gap_count")),
    "voiced_coverage_pct": voiced_coverage_pct,
    "target_window_coverage_pct": target_window_coverage_pct,
    "target_coverage_pct": target_coverage_pct,
    "on_target_rate_pct": _metric_value(raw, "on_target_rate_pct"),
    "mean_confidence": min(max(_safe_float(raw.get("mean_confidence")), 0.0), 1.0),
    "confidence_stddev": min(max(_safe_float(raw.get("confidence_stddev")), 0.0), 1.0),
    "mean_loudness_db": (
      None
      if raw.get("mean_loudness_db") is None
      else min(max(_safe_float(raw.get("mean_loudness_db")), -120.0), 10.0)
    ),
    "loudness_stddev_db": max(_safe_float(raw.get("loudness_stddev_db")), 0.0),
    "mean_abs_cents": min(max(_safe_float(raw.get("mean_abs_cents")), 0.0), 1200.0),
    "p95_abs_cents": min(max(_safe_float(raw.get("p95_abs_cents")), 0.0), 1200.0),
    "pitch_bias_cents": min(max(_safe_float(raw.get("pitch_bias_cents")), -1200.0), 1200.0),
    "pitch_stddev_cents": min(max(_safe_float(raw.get("pitch_stddev_cents")), 0.0), 1200.0),
    "mean_onset_delay_ms": max(_safe_float(raw.get("mean_onset_delay_ms")), 0.0),
    "p95_onset_delay_ms": max(_safe_float(raw.get("p95_onset_delay_ms")), 0.0),
    "late_onset_count": _safe_int(raw.get("late_onset_count")),
    "mean_settling_time_ms": max(_safe_float(raw.get("mean_settling_time_ms")), 0.0),
    "mean_zero_crossing_rate": (
      None if raw.get("mean_zero_crossing_rate") is None else min(max(_safe_float(raw.get("mean_zero_crossing_rate")), 0.0), 1.0)
    ),
    "mean_spectral_centroid_hz": (
      None if raw.get("mean_spectral_centroid_hz") is None else min(max(_safe_float(raw.get("mean_spectral_centroid_hz")), 0.0), 24000.0)
    ),
    "mean_spectral_rolloff_hz": (
      None if raw.get("mean_spectral_rolloff_hz") is None else min(max(_safe_float(raw.get("mean_spectral_rolloff_hz")), 0.0), 24000.0)
    ),
    "mean_crest_factor_db": (
      None if raw.get("mean_crest_factor_db") is None else min(max(_safe_float(raw.get("mean_crest_factor_db")), 0.0), 100.0)
    ),
    "clipping_ratio_pct": (
      None if raw.get("clipping_ratio_pct") is None else min(max(_safe_float(raw.get("clipping_ratio_pct")), 0.0), 100.0)
    ),
    "mean_periodicity": (
      None if raw.get("mean_periodicity") is None else min(max(_safe_float(raw.get("mean_periodicity")), 0.0), 1.0)
    ),
    "longest_voiced_run_ms": _safe_int(raw.get("longest_voiced_run_ms")),
    "voiced_run_count": _safe_int(raw.get("voiced_run_count")),
    "interruption_count": _safe_int(raw.get("interruption_count")),
    "transition_count": _safe_int(raw.get("transition_count")),
    "completed_transition_count": _safe_int(raw.get("completed_transition_count")),
    "failed_transition_count": _safe_int(raw.get("failed_transition_count")),
    "vibrato_detected": bool(raw.get("vibrato_detected", False)),
    "vibrato_rate_hz": raw.get("vibrato_rate_hz"),
    "vibrato_amplitude_cents": raw.get("vibrato_amplitude_cents"),
    "vibrato_regularity_pct": raw.get("vibrato_regularity_pct"),
    "segments": list(raw.get("segments") or [])[:64],
  }, True


def _normalized_breathing_evidence(
  metric_summary: dict[str, Any],
) -> tuple[dict[str, Any], bool]:
  raw = _raw_evidence(metric_summary)
  if raw is None:
    return {
      "duration_ms": max(
        0,
        _safe_int(metric_summary.get("last_timestamp_ms"))
        - _safe_int(metric_summary.get("first_timestamp_ms")),
      ),
      "phase_count": 0,
      "completed_phase_count": 0,
      "phase_coverage_pct": 0.0,
      "interruption_count": _safe_int(metric_summary.get("interruption_count")),
      "audio_frame_count": 0,
      "audible_frame_count": 0,
      "audible_coverage_pct": 0.0,
      "mean_loudness_db": None,
      "loudness_stddev_db": None,
      "audio_observed_duration_ms": 0,
      "audio_evidence_note": None,
      "detailed_evidence": False,
    }, False

  phase_count = _safe_int(raw.get("phase_count"))
  completed_phase_count = min(
    _safe_int(raw.get("completed_phase_count")),
    phase_count,
  )
  phase_coverage_pct = round(
    (completed_phase_count / phase_count * 100) if phase_count else 0.0,
    2,
  )
  return {
    "duration_ms": _safe_int(raw.get("duration_ms")),
    "phase_count": phase_count,
    "completed_phase_count": completed_phase_count,
    "phase_coverage_pct": phase_coverage_pct,
    "interruption_count": _safe_int(raw.get("interruption_count")),
    "audio_frame_count": _safe_int(raw.get("audio_frame_count")),
    "audible_frame_count": _safe_int(raw.get("audible_frame_count")),
    "audible_coverage_pct": min(max(_safe_float(raw.get("audible_coverage_pct")), 0.0), 100.0),
    "mean_loudness_db": (
      None if raw.get("mean_loudness_db") is None else min(max(_safe_float(raw.get("mean_loudness_db")), -120.0), 10.0)
    ),
    "loudness_stddev_db": max(_safe_float(raw.get("loudness_stddev_db")), 0.0),
    "audio_observed_duration_ms": _safe_int(raw.get("audio_observed_duration_ms")),
    "audio_evidence_note": raw.get("audio_evidence_note"),
    "detailed_evidence": True,
  }, True


def _metric_detail(
  *,
  metric: str,
  score: float,
  metric_mode: str,
  evidence: dict[str, Any],
) -> dict[str, Any]:
  frame_count = _safe_int(evidence.get("frame_count"))
  voiced_count = _safe_int(evidence.get("voiced_frame_count"))
  target_count = _safe_int(evidence.get("target_frame_count"))
  target_coverage = _safe_float(evidence.get("target_coverage_pct"))
  voiced_coverage = _safe_float(evidence.get("voiced_coverage_pct"))

  detail: dict[str, Any] = {
    "score": score,
    "status": "measured",
    "reason": "Measured from the captured audio evidence.",
    "observed_frames": voiced_count,
    "coverage_pct": voiced_coverage,
    "action": _METRIC_DETAIL_ACTIONS.get(metric, "Repeat this exercise slowly and focus on the measured result."),
  }

  if metric_mode == "breathing":
    phase_count = _safe_int(evidence.get("phase_count"))
    completed_phase_count = _safe_int(evidence.get("completed_phase_count"))
    phase_coverage = _safe_float(evidence.get("phase_coverage_pct"))
    interruption_count = _safe_int(evidence.get("interruption_count"))
    interruption_label = "interruption" if interruption_count == 1 else "interruptions"
    if not evidence.get("detailed_evidence", False):
      detail.update({
        "status": "partial",
        "reason": (
          "This older take saved the breathing scores but not the phase-by-phase event evidence, "
          "so the exact completed phases cannot be located."
        ),
        "observed_frames": 0,
        "coverage_pct": 0.0,
      })
      return detail
    if phase_count <= 0:
      detail.update({
        "status": "not_measurable",
        "reason": "No breathing phases were captured, so this part was not measurable.",
        "observed_frames": 0,
        "coverage_pct": 0.0,
      })
      return detail

    detail["observed_frames"] = completed_phase_count
    detail["coverage_pct"] = phase_coverage
    if metric == "phase_completion_rate":
      detail["reason"] = (
        f"{completed_phase_count} of {phase_count} guided breathing phases were completed."
      )
    elif metric == "pace_adherence":
      detail["reason"] = (
        f"The guided routine recorded {completed_phase_count} of {phase_count} completed phases "
        f"and {interruption_count} {interruption_label}."
      )
    elif metric == "cycle_consistency":
      detail["reason"] = (
        f"Cycle consistency was measured across {phase_count} guided phases with "
        f"{interruption_count} {interruption_label}."
      )
    elif metric == "completion_rate":
      detail["reason"] = (
        f"The recording completed {completed_phase_count} of {phase_count} guided phases."
      )
    audio_frame_count = _safe_int(evidence.get("audio_frame_count"))
    if audio_frame_count:
      detail["reason"] += (
        f" Optional microphone evidence heard audible sound in "
        f"{_safe_float(evidence.get('audible_coverage_pct')):.0f}% of audio frames; "
        "this does not measure airflow."
      )
    else:
      detail["reason"] += " Timer evidence was available; optional microphone audio was not captured."
    if detail["status"] == "measured" and phase_coverage < 80:
      detail["status"] = "partial"
    return detail

  if metric_mode == "voice":
    if metric == "note_transition_smoothness" and evidence["transition_count"] == 0:
      detail.update({
        "status": "not_applicable",
        "reason": "This take did not contain a guided note change, so note-transition smoothness was not tested.",
        "observed_frames": 0,
        "coverage_pct": 0.0,
      })
      return detail
    if metric in _TARGET_COMPARISON_METRICS and target_count <= 0:
      if evidence["no_target_frame_count"] >= max(frame_count, 1):
        reason = (
          "No target-note comparison frames were captured because the target guide was not available in this take. "
          "The 0/100 is not a failed singing result; this part was not measurable."
        )
      elif voiced_count <= 0:
        reason = (
          "Target notes were present, but no confident voiced frames overlapped them. "
          "The 0/100 is not a failed singing result; the comparison needs a clearer recording."
        )
      else:
        reason = (
          "No confident target-note comparison frames were available, so this part was not measurable."
        )
      detail.update({
        "status": "not_measurable",
        "reason": reason,
        "observed_frames": target_count,
        "coverage_pct": target_coverage,
      })
      return detail

    if metric == "pitch_accuracy":
      detail["reason"] = (
        f"{evidence['on_target_rate_pct']:.0f}% of {target_count} confident target frames were within the target window; "
        f"mean pitch error was {evidence['mean_abs_cents']:.0f} cents."
      )
      detail["observed_frames"] = target_count
      detail["coverage_pct"] = target_coverage
    elif metric == "timing_accuracy":
      detail["reason"] = (
        f"The voice covered {target_coverage:.0f}% of target-note frames; average target entry "
        f"delay was {evidence['mean_onset_delay_ms']:.0f} ms and "
        f"{evidence['late_onset_count']} target(s) started later than 250 ms."
      )
      detail["observed_frames"] = target_count
      detail["coverage_pct"] = target_coverage
    elif metric == "pitch_stability":
      detail["reason"] = (
        f"Pitch variation around the average note center was {evidence['pitch_stddev_cents']:.0f} cents "
        f"across {target_count} target frames."
      )
      detail["observed_frames"] = target_count
      detail["coverage_pct"] = target_coverage
    elif metric == "vibrato_consistency":
      if evidence["vibrato_detected"]:
        detail["reason"] = (
          f"Detected approximately {float(evidence['vibrato_rate_hz'] or 0):.1f} Hz movement at "
          f"{float(evidence['vibrato_amplitude_cents'] or 0):.0f} cents amplitude, with "
          f"{float(evidence['vibrato_regularity_pct'] or 0):.0f}% regularity."
        )
      else:
        detail["status"] = "partial"
        detail["reason"] = (
          "No repeated vibrato cycle was detected. This metric stays neutral rather than treating a straight tone as a failure."
        )
      detail["observed_frames"] = target_count
      detail["coverage_pct"] = target_coverage
    elif metric == "note_transition_smoothness":
      detail["reason"] = (
        f"{evidence['completed_transition_count']} of {evidence['transition_count']} guided note changes settled "
        f"successfully; {evidence['failed_transition_count']} did not settle within the observation window."
      )
      detail["observed_frames"] = target_count
      detail["coverage_pct"] = target_coverage
    elif metric == "breath_control":
      if voiced_count <= 0:
        detail.update({
          "status": "not_measurable",
          "reason": (
            "No confident voiced frames were captured, so breath steadiness could not be estimated "
            "from the microphone signal. This 0/100 is missing evidence, not a diagnosis."
          ),
          "observed_frames": 0,
          "coverage_pct": 0.0,
        })
        return detail
      detail["reason"] = (
        f"Estimated from {voiced_coverage:.0f}% voiced coverage, "
        f"{evidence['voiced_run_count']} voiced run(s), and "
        f"{_safe_float(evidence.get('loudness_stddev_db')):.1f} dB loudness variation. "
        "This is a continuity/loudness proxy, not direct airflow measurement."
      )
      detail["observed_frames"] = voiced_count
      detail["coverage_pct"] = voiced_coverage

    coverage_for_metric = (
      target_coverage
      if metric in _TARGET_COMPARISON_METRICS
      else voiced_coverage
    )
    if detail["status"] == "measured" and coverage_for_metric < 80:
      detail["status"] = "partial"
  return detail


def _normalized_segments(raw_segments: list[Any]) -> list[dict[str, Any]]:
  segments: list[dict[str, Any]] = []
  for raw in raw_segments:
    if hasattr(raw, "model_dump"):
      raw = raw.model_dump()
    if not isinstance(raw, dict) or not str(raw.get("segment_id") or "").strip():
      continue
    segment = dict(raw)
    target_count = _safe_int(segment.get("target_frame_count"))
    frame_count = _safe_int(segment.get("frame_count"))
    if target_count <= 0:
      segment["status"] = "not_measurable"
      segment["reason"] = segment.get("reason") or "No confident target-note frames were captured in this segment."
    else:
      segment["status"] = segment.get("status") or "measured"
      segment["reason"] = segment.get("reason") or (
        f"{_metric_value(segment, 'on_target_rate_pct'):.0f}% of the confident target frames were on target."
      )
    segment["frame_count"] = frame_count
    segment["target_frame_count"] = target_count
    segment["score"] = _metric_value(segment, "score")
    segments.append(segment)
  return segments


def score_training_attempt(
  *,
  exercise_id: str,
  metric_summary: dict[str, Any],
) -> dict[str, Any]:
  exercise = get_exercise(exercise_id) or {}
  metric_mode = metric_mode_for_exercise(exercise_id)
  metric_fields = metric_fields_for_exercise(exercise_id)
  weights = _normalized_metric_weights(exercise_id, metric_fields)
  metric_scores = {
    field: _metric_value(metric_summary, field)
    for field in metric_fields
  }
  if metric_mode == "breathing":
    recording_evidence, has_detailed_evidence = _normalized_breathing_evidence(metric_summary)
  else:
    recording_evidence, has_detailed_evidence = _normalized_recording_evidence(metric_summary)
  metric_details = {
    field: _metric_detail(
      metric=field,
      score=metric_scores[field],
      metric_mode=metric_mode,
      evidence=recording_evidence,
    )
    for field in metric_fields
  }
  segments = _normalized_segments(recording_evidence.get("segments", []))
  weighted_components = {
    field: round(metric_scores[field] * weights[field], 2)
    for field in metric_fields
  }
  overall_score = round(sum(weighted_components.values()), 2)
  evidence_quality = _evidence_quality(metric_summary)
  score_status = _score_status(
    metric_mode=metric_mode,
    evidence_quality=evidence_quality,
    evidence=recording_evidence,
    has_detailed_evidence=has_detailed_evidence,
  )

  default_focus_metrics = list(metric_fields[:3])
  focus_metrics = [
    field
    for field in list(exercise.get("focus_metrics") or default_focus_metrics)
    if field in metric_fields
  ] or default_focus_metrics
  ranked_focus_metrics = sorted(
    [
      field
      for field in focus_metrics
      if not has_detailed_evidence
      or metric_details[field]["status"] not in {"not_measurable", "not_applicable"}
    ] or focus_metrics,
    key=lambda field: metric_scores.get(field, 0.0),
  )
  weakest_metric = ranked_focus_metrics[0] if ranked_focus_metrics else metric_fields[0]
  strongest_metric = ranked_focus_metrics[-1] if ranked_focus_metrics else metric_fields[0]

  thresholds = dict(exercise.get("success_thresholds") or {})
  overall_threshold = min(max(_safe_float(thresholds.get("overall_score")), 0.0), 100.0)
  metric_floors = {
    field: min(max(_safe_float(value), 0.0), 100.0)
    for field, value in dict(thresholds.get("metric_floors") or {}).items()
    if field in metric_fields
  }
  passed_threshold = score_status in {"measured", "legacy"} and overall_score >= overall_threshold and all(
    metric_scores.get(field, 0.0) >= value
    for field, value in metric_floors.items()
  )
  if has_detailed_evidence and metric_mode == "voice":
    passed_threshold = passed_threshold and recording_evidence["target_frame_count"] > 0

  return {
    "overall_score": overall_score,
    "score_breakdown": {
      "metric_mode": metric_mode,
      "focus_metrics": focus_metrics,
      "metric_scores": metric_scores,
      "weighted_components": weighted_components,
      "scoring_version": SCORING_VERSION,
      "sample_count": max(0, int(_safe_float(metric_summary.get("sample_count"), 0.0))),
      "evidence_quality": evidence_quality,
      "score_status": score_status,
      "score_reliability": score_status,
      "legacy_evidence": not has_detailed_evidence,
      "recording_evidence": recording_evidence,
      "metric_details": metric_details,
      "segments": segments,
    },
    "strongest_metric": strongest_metric,
    "weakest_metric": weakest_metric,
    "passed_threshold": passed_threshold,
  }
