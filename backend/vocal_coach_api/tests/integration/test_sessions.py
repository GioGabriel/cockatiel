def _create_session(client, auth_headers) -> str:
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={"mode": "training", "exercise_type": "warmup_pitch"},
  )
  assert response.status_code == 201
  return response.json()["session_id"]


def _metric_payload(session_id: str) -> dict[str, object]:
  return {
    "metrics": [
      {
        "session_id": session_id,
        "timestamp_ms": 1,
        "exercise_type": "warmup_pitch",
        "pitch_accuracy": 70,
        "timing_accuracy": 75,
        "breath_control": 68,
        "pitch_stability": 72,
        "vibrato_consistency": 64,
        "note_transition_smoothness": 71,
      },
      {
        "session_id": session_id,
        "timestamp_ms": 2,
        "exercise_type": "warmup_pitch",
        "pitch_accuracy": 74,
        "timing_accuracy": 77,
        "breath_control": 70,
        "pitch_stability": 73,
        "vibrato_consistency": 66,
        "note_transition_smoothness": 72,
      },
    ]
  }


def test_sessions_vertical_slice_flow(client, auth_headers, expected_feedback_models):
  session_id = _create_session(client, auth_headers)

  metrics_response = client.post(
    f"/v1/sessions/{session_id}/metrics",
    headers=auth_headers,
    json=_metric_payload(session_id),
  )
  assert metrics_response.status_code == 202
  assert metrics_response.json()["accepted_count"] == 2

  finalize_response = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert finalize_response.status_code == 200
  finalize_payload = finalize_response.json()
  assert finalize_payload["status"] == "completed"
  assert finalize_payload["feedback"]["session_id"] == session_id
  assert finalize_payload["feedback"]["model_used"] == "coaching-logic-engine"
  assert finalize_payload["feedback"]["prompt_version"] in {"v1", "v1a", "v1b"}

  session_response = client.get(f"/v1/sessions/{session_id}", headers=auth_headers)
  assert session_response.status_code == 200
  session_payload = session_response.json()
  assert session_payload["status"] == "completed"
  assert session_payload["feedback"] is not None

  feedback_response = client.get(f"/v1/sessions/{session_id}/feedback", headers=auth_headers)
  assert feedback_response.status_code == 200
  assert feedback_response.json()["session_id"] == session_id


def test_sessions_rejects_metric_session_id_mismatch(client, auth_headers):
  session_id = _create_session(client, auth_headers)

  payload = _metric_payload("another-session")
  response = client.post(
    f"/v1/sessions/{session_id}/metrics",
    headers=auth_headers,
    json=payload,
  )
  assert response.status_code == 400
  assert response.json()["error"]["code"] == "SESSION_ID_MISMATCH"


def test_sessions_finalize_rejects_completed_session(client, auth_headers):
  session_id = _create_session(client, auth_headers)

  client.post(f"/v1/sessions/{session_id}/metrics", headers=auth_headers, json=_metric_payload(session_id))
  first_finalize = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert first_finalize.status_code == 200

  second_finalize = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert second_finalize.status_code == 409
  assert second_finalize.json()["error"]["code"] == "SESSION_STATE_INVALID"
