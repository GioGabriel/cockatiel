from app.repositories.provider import get_repository_bundle


def _complete_training_session(client, auth_headers) -> str:
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
          "pitch_accuracy": 71,
          "timing_accuracy": 73,
          "breath_control": 69,
          "pitch_stability": 70,
          "vibrato_consistency": 65,
          "note_transition_smoothness": 72,
        }
      ]
    },
  )
  assert metrics_response.status_code == 202

  finalize_response = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert finalize_response.status_code == 200
  return session_id


def _complete_breathing_session(client, auth_headers) -> str:
  create_response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={"mode": "training", "exercise_type": "breath_support_ladder"},
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
        "metric_mode": "breathing",
        "sample_count": 30,
        "phase_completion_rate": 92,
        "pace_adherence": 88,
        "cycle_consistency": 84,
        "completion_rate": 100,
        "interruption_count": 1,
      },
    },
  )
  assert attempt_response.status_code == 201

  finalize_response = client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)
  assert finalize_response.status_code == 200
  return session_id


def test_analytics_dashboard_empty_state(client, auth_headers):
  response = client.get("/v1/analytics/dashboard", headers=auth_headers)

  assert response.status_code == 200
  payload = response.json()
  assert payload["user_id"] == "test-user"
  assert payload["total_completed_sessions"] == 0
  assert payload["avg_score_7d"] == 0
  assert payload["ranges"]["7d"]["session_count"] == 0


def test_analytics_dashboard_updates_after_session_finalize(client, auth_headers):
  _complete_training_session(client, auth_headers)

  response = client.get("/v1/analytics/dashboard", headers=auth_headers)
  assert response.status_code == 200
  payload = response.json()

  assert payload["total_completed_sessions"] == 1
  assert payload["streak_days"] >= 1
  assert payload["avg_score_7d"] > 0
  assert payload["last_session_at"] is not None
  assert payload["ranges"]["7d"]["session_count"] == 1
  assert payload["ranges"]["30d"]["session_count"] == 1
  assert payload["ranges"]["90d"]["session_count"] == 1
  assert payload["ranges"]["7d"]["primary_metric_mode"] == "voice"
  assert payload["ranges"]["7d"]["primary_metrics"][0]["metric_key"] == "pitch_accuracy"


def test_analytics_dashboard_uses_breathing_primary_metrics(client, auth_headers):
  _complete_breathing_session(client, auth_headers)

  response = client.get("/v1/analytics/dashboard", headers=auth_headers)
  assert response.status_code == 200
  payload = response.json()

  assert payload["ranges"]["7d"]["primary_metric_mode"] == "breathing"
  assert payload["ranges"]["7d"]["primary_metrics"] == [
    {
      "metric_key": "phase_completion_rate",
      "label": "Phase completion",
      "avg_value": 92.0,
      "session_count": 1,
    },
    {
      "metric_key": "pace_adherence",
      "label": "Pace adherence",
      "avg_value": 88.0,
      "session_count": 1,
    },
    {
      "metric_key": "cycle_consistency",
      "label": "Cycle consistency",
      "avg_value": 84.0,
      "session_count": 1,
    },
  ]


def test_analytics_trends_default_range(client, auth_headers):
  response = client.get("/v1/analytics/trends", headers=auth_headers)

  assert response.status_code == 200
  payload = response.json()
  assert payload["user_id"] == "test-user"
  assert payload["range"] == "30d"
  assert len(payload["points"]) == 30


def test_analytics_trends_contains_completed_session_data(client, auth_headers):
  _complete_training_session(client, auth_headers)

  response = client.get("/v1/analytics/trends?range=7d", headers=auth_headers)
  assert response.status_code == 200
  payload = response.json()

  assert payload["range"] == "7d"
  assert len(payload["points"]) == 7
  assert any(point["session_count"] > 0 for point in payload["points"])


def test_daily_rollup_cache_is_populated_after_finalize(client, auth_headers):
  _complete_training_session(client, auth_headers)

  analytics_repository = get_repository_bundle().analytics
  rollups = analytics_repository.list_daily_rollups("test-user")
  assert len(rollups) == 1
  assert rollups[0]["session_count"] == 1
