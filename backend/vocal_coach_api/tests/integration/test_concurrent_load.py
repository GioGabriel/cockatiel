import concurrent.futures

from tests.integration.test_sessions import _create_session, _metric_payload


def test_concurrent_finalize_handles_threadpool_saturation_and_race_conditions(
  client, auth_headers
):
  """
  Tests that blasting the /finalize endpoint with concurrent requests:
  1. Does not crash the threadpool.
  2. Protects against race conditions.
  """
  # Create a session synchronously
  session_id = _create_session(client, auth_headers)

  # Metrics
  metrics_resp = client.post(
    f"/v1/sessions/{session_id}/metrics",
    headers=auth_headers,
    json=_metric_payload(session_id),
  )
  assert metrics_resp.status_code == 202

  # Blast finalize concurrently using threads
  def _finalize():
    return client.post(f"/v1/sessions/{session_id}/finalize", headers=auth_headers)

  with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
    futures = [executor.submit(_finalize) for _ in range(20)]
    responses = [f.result() for f in concurrent.futures.as_completed(futures)]

  # We expect at least one to succeed with 200, and the rest to fail with 409
  successes = [r for r in responses if r.status_code == 200]
  conflicts = [r for r in responses if r.status_code == 409]

  assert len(successes) == 1
  assert len(conflicts) == 19
  assert successes[0].json()["status"] in {"completed", "processing"}
  assert conflicts[0].json()["error"]["code"] == "SESSION_STATE_INVALID"
