from types import SimpleNamespace

from app.queue.consumers.ai_evaluation import process_next_ai_evaluation_job


def test_async_finalize_processes_queue_job(client, auth_headers, monkeypatch, expected_feedback_models):
  from app.api.v1.endpoints import sessions as sessions_endpoint

  monkeypatch.setattr(sessions_endpoint, "settings", SimpleNamespace(ai_async_enabled=True))

  create_response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={"mode": "training", "exercise_type": "warmup_pitch"},
  )
  assert create_response.status_code == 201
  session_id = create_response.json()["session_id"]

  metrics_response = client.post(
    f"/v1/sessions/{session_id}/metrics",
    headers=auth_headers,
    json={
      "metrics": [
        {
          "session_id": session_id,
          "timestamp_ms": 1,
          "exercise_type": "warmup_pitch",
          "pitch_accuracy": 72,
          "timing_accuracy": 73,
          "breath_control": 70,
          "pitch_stability": 71,
          "vibrato_consistency": 66,
          "note_transition_smoothness": 72,
        }
      ]
    },
  )
  assert metrics_response.status_code == 202

  finalize_response = client.post(
    f"/v1/sessions/{session_id}/finalize",
    headers=auth_headers,
  )
  assert finalize_response.status_code == 200
  finalize_payload = finalize_response.json()
  assert finalize_payload["status"] == "processing"
  assert finalize_payload["feedback"] is None
  assert isinstance(finalize_payload["job_id"], str)

  jobs_response = client.get("/v1/ai/jobs", headers=auth_headers)
  assert jobs_response.status_code == 200
  jobs_payload = jobs_response.json()
  assert len(jobs_payload) >= 1
  assert jobs_payload[0]["job_id"] == finalize_payload["job_id"]
  assert jobs_payload[0]["state"] in {"queued", "processing"}

  processed = process_next_ai_evaluation_job()
  assert processed is True

  session_response = client.get(f"/v1/sessions/{session_id}", headers=auth_headers)
  assert session_response.status_code == 200
  session_payload = session_response.json()
  assert session_payload["status"] == "completed"
  assert session_payload["feedback"]["model_used"] in expected_feedback_models
  assert session_payload["ai_job"]["state"] == "completed"

  feedback_response = client.get(f"/v1/sessions/{session_id}/feedback", headers=auth_headers)
  assert feedback_response.status_code == 200
