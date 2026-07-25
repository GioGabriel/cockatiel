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
      "sample_count": 5,
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
