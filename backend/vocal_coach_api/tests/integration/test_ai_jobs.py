from types import SimpleNamespace


def test_ai_jobs_list_and_detail(client, auth_headers, monkeypatch):
  from app.api.v1.endpoints import sessions as sessions_endpoint

  monkeypatch.setattr(sessions_endpoint, "settings", SimpleNamespace(ai_async_enabled=True))

  create_response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={"mode": "training", "exercise_type": "warmup_pitch"},
  )
  assert create_response.status_code == 201
  session_id = create_response.json()["session_id"]

  attempt_response = client.post(
    f"/v1/sessions/{session_id}/attempts",
    headers=auth_headers,
    json={
      "attempt_index": 1,
      "difficulty": "beginner",
      "duration_sec": 30,
      "metric_summary": {
        "sample_count": 5,
        "pitch_accuracy": 72,
        "timing_accuracy": 73,
        "breath_control": 71,
        "pitch_stability": 74,
        "vibrato_consistency": 66,
        "note_transition_smoothness": 70,
      },
    },
  )
  assert attempt_response.status_code == 201

  finalize_response = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert finalize_response.status_code == 200
  job_id = finalize_response.json()["job_id"]
  assert isinstance(job_id, str)

  list_response = client.get("/v1/ai/jobs", headers=auth_headers)
  assert list_response.status_code == 200
  jobs = list_response.json()
  assert any(item["job_id"] == job_id for item in jobs)

  detail_response = client.get(f"/v1/ai/jobs/{job_id}", headers=auth_headers)
  assert detail_response.status_code == 200
  detail = detail_response.json()
  assert detail["job_id"] == job_id
  assert detail["session_id"] == session_id
  assert detail["state"] in {"queued", "processing"}
