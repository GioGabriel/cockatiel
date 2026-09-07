"""Production-facing handling for exhausted persistent-storage quotas."""

from google.api_core.exceptions import ResourceExhausted


def test_firestore_quota_failure_is_a_retryable_dependency_error(
  client,
  auth_headers,
  monkeypatch,
):
  def fail_upsert(_: dict) -> dict:
    raise ResourceExhausted("Quota exceeded.")

  monkeypatch.setattr(
    "app.api.v1.endpoints.auth.upsert_user",
    fail_upsert,
  )

  response = client.get("/v1/auth/me", headers=auth_headers)

  assert response.status_code == 503
  assert response.headers["retry-after"] == "60"
  error = response.json()["error"]
  assert error["code"] == "STORAGE_QUOTA_EXCEEDED"
  assert error["message"] == "Account data is temporarily unavailable. Please try again shortly."
  assert error["details"] == {"retry_after_seconds": 60}
  assert error["trace_id"]
