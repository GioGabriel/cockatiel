def _create_training_session(
  client,
  auth_headers,
  *,
  exercise_type: str = "resonance_placement",
) -> str:
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={
      "mode": "training",
      "exercise_type": exercise_type,
      "training_config": {"difficulty": "beginner"},
    },
  )
  assert response.status_code == 201
  return response.json()["session_id"]


def _voice_attempt_payload(*, index: int, score_seed: float) -> dict[str, object]:
  return {
    "attempt_index": index,
    "difficulty": "beginner",
    "duration_sec": 30,
    "metric_summary": {
      "sample_count": 64,
      "pitch_accuracy": score_seed + 2,
      "timing_accuracy": score_seed + 1,
      "breath_control": score_seed,
      "pitch_stability": score_seed + 1,
      "vibrato_consistency": score_seed - 2,
      "note_transition_smoothness": score_seed + 1,
    },
  }


def _breathing_attempt_payload(*, index: int) -> dict[str, object]:
  return {
    "attempt_index": index,
    "difficulty": "beginner",
    "duration_sec": 30,
    "metric_summary": {
      "metric_mode": "breathing",
      "sample_count": 30,
      "phase_completion_rate": 92,
      "pace_adherence": 88,
      "cycle_consistency": 84,
      "completion_rate": 100,
      "interruption_count": 1,
    },
  }


def test_training_attempt_auto_selects_best(client, auth_headers):
  session_id = _create_training_session(client, auth_headers)

  first = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=_voice_attempt_payload(index=1, score_seed=70),
  )
  assert first.status_code == 201
  first_payload = first.json()
  assert first_payload["attempt"]["is_best"] is True
  assert first_payload["attempt"]["strongest_metric"] == "pitch_accuracy"
  assert first_payload["attempt"]["score_breakdown"]["focus_metrics"] == [
    "breath_control",
    "pitch_stability",
    "pitch_accuracy",
  ]

  second = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=_voice_attempt_payload(index=2, score_seed=65),
  )
  assert second.status_code == 201
  second_payload = second.json()
  assert second_payload["attempt"]["is_best"] is False
  assert second_payload["selected_best_attempt_id"] == first_payload["selected_best_attempt_id"]

  third = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=_voice_attempt_payload(index=3, score_seed=80),
  )
  assert third.status_code == 201
  third_payload = third.json()
  assert third_payload["attempt"]["is_best"] is True
  assert third_payload["selected_best_attempt_id"] == third_payload["attempt"]["attempt_id"]
  assert third_payload["attempt"]["passed_threshold"] is True

  session_response = client.get(f"/v1/sessions/{session_id}", headers=auth_headers)
  assert session_response.status_code == 200
  session_payload = session_response.json()
  assert len(session_payload["attempts"]) == 3
  assert session_payload["selected_best_attempt_id"] == third_payload["attempt"]["attempt_id"]

  finalize = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert finalize.status_code == 200
  assert finalize.json()["status"] == "completed"


def test_voice_attempt_rejects_insufficient_audio_evidence(client, auth_headers):
  session_id = _create_training_session(client, auth_headers)
  payload = _voice_attempt_payload(index=1, score_seed=95)
  payload["metric_summary"]["sample_count"] = 8

  response = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=payload,
  )

  assert response.status_code == 422
  assert response.json()["error"]["code"] == "INSUFFICIENT_AUDIO_EVIDENCE"


def test_training_attempt_enforces_default_max_attempts(client, auth_headers):
  session_id = _create_training_session(client, auth_headers)

  for index in range(1, 4):
    response = client.post(
      f"/v1/sessions/{session_id}/attempts",
      headers=auth_headers,
      json=_voice_attempt_payload(index=index, score_seed=65 + index),
    )
    assert response.status_code == 201

  fourth = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=_voice_attempt_payload(index=4, score_seed=90),
  )
  assert fourth.status_code == 409
  assert fourth.json()["error"]["code"] == "MAX_ATTEMPTS_REACHED"


def test_breathing_attempt_uses_breathing_metric_contract(client, auth_headers):
  session_id = _create_training_session(
    client,
    auth_headers,
    exercise_type="breath_support_ladder",
  )

  response = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=_breathing_attempt_payload(index=1),
  )
  assert response.status_code == 201

  payload = response.json()
  metric_summary = payload["attempt"]["metric_summary"]
  score_breakdown = payload["attempt"]["score_breakdown"]

  assert metric_summary["metric_mode"] == "breathing"
  assert metric_summary["phase_completion_rate"] == 92
  assert metric_summary["interruption_count"] == 1
  assert "pitch_accuracy" not in metric_summary
  assert score_breakdown["metric_mode"] == "breathing"
  assert score_breakdown["focus_metrics"] == [
    "phase_completion_rate",
    "pace_adherence",
    "cycle_consistency",
  ]


def test_attempt_contract_accepts_onset_and_acoustic_evidence(client, auth_headers):
  session_id = _create_training_session(client, auth_headers)
  payload = _voice_attempt_payload(index=1, score_seed=75)
  payload["metric_summary"]["evidence"] = {
    "frame_count": 64,
    "voiced_frame_count": 60,
    "target_window_frame_count": 64,
    "target_frame_count": 60,
    "voiced_coverage_pct": 93.75,
    "target_window_coverage_pct": 100,
    "target_coverage_pct": 93.75,
    "on_target_rate_pct": 82,
    "mean_onset_delay_ms": 140,
    "p95_onset_delay_ms": 260,
    "late_onset_count": 1,
    "mean_settling_time_ms": 90,
    "mean_zero_crossing_rate": 0.05,
    "mean_spectral_centroid_hz": 820,
    "mean_spectral_rolloff_hz": 2100,
    "mean_crest_factor_db": 12,
    "clipping_ratio_pct": 0,
    "mean_periodicity": 0.9,
    "segments": [
      {
        "segment_id": "target-a",
        "label": "Do",
        "frame_count": 64,
        "voiced_frame_count": 60,
        "target_frame_count": 60,
        "onset_delay_ms": 140,
        "settling_time_ms": 90,
        "score": 82,
      },
    ],
  }

  response = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=payload,
  )

  assert response.status_code == 201
  evidence = response.json()["attempt"]["score_breakdown"]["recording_evidence"]
  assert evidence["mean_onset_delay_ms"] == 140
  assert evidence["mean_spectral_centroid_hz"] == 820


def test_attempt_contract_normalizes_missing_percentile_evidence(client, auth_headers):
  session_id = _create_training_session(client, auth_headers)
  payload = _voice_attempt_payload(index=1, score_seed=75)
  payload["metric_summary"]["evidence"] = {
    "p95_abs_cents": None,
    "segments": [
      {"segment_id": "target-a", "p95_abs_cents": None},
      {"segment_id": "target-b", "p95_abs_cents": 84.5},
    ],
  }

  response = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=payload,
  )

  assert response.status_code == 201
  evidence = response.json()["attempt"]["metric_summary"]["evidence"]
  assert evidence["p95_abs_cents"] == 0
  assert evidence["segments"][0]["p95_abs_cents"] == 0
  assert evidence["segments"][1]["p95_abs_cents"] == 84.5


def test_karaoke_attempt_saves_and_finalizes(client, auth_headers):
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={
      "mode": "karaoke",
      "exercise_type": "bohemian_rhapsody",
      "training_config": {"difficulty": "intermediate"},
    },
  )
  assert response.status_code == 201
  session_id = response.json()["session_id"]

  attempt_resp = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json=_voice_attempt_payload(index=1, score_seed=82),
  )
  assert attempt_resp.status_code == 201
  assert attempt_resp.json()["attempt"]["score"] > 0
