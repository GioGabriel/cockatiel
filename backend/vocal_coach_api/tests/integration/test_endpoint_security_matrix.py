"""Security checks follow the actual route surface so new routes cannot hide gaps."""
import base64
import re

import pytest

from app.core.exceptions import ApiError
from app.main import app


PUBLIC = {"/health", "/v1/training/catalog", "/v1/karaoke/catalog/preview"}
OPERATIONS = [
  (method.upper(), path)
  for path, operations in app.openapi()["paths"].items()
  for method in operations
  if method in {"get", "post", "put", "patch", "delete"} and path not in PUBLIC | {"/metrics"}
]


@pytest.mark.parametrize("method,path", OPERATIONS)
@pytest.mark.parametrize("authorization", [None, "Basic invalid", "Bearer ", "Bearer rejected-token"])
def test_every_private_operation_rejects_missing_malformed_or_rejected_credentials(
  client, monkeypatch, method, path, authorization
):
  from app.api.v1.dependencies import firebase_verifier

  def reject(_token):
    raise ApiError(code="AUTH_INVALID", message="Authentication token is invalid or expired.", status_code=401)

  monkeypatch.setattr(firebase_verifier, "verify", reject)
  headers = {"Authorization": authorization} if authorization is not None else {}
  response = client.request(method, re.sub(r"\{[^}]+\}", "unknown-resource", path), headers=headers)
  assert response.status_code == 401, (method, path, response.text)
  assert response.json()["error"]["code"] in {"AUTH_MISSING", "AUTH_INVALID"}
  assert response.headers["x-request-id"]


@pytest.mark.parametrize("path", sorted(PUBLIC - {"/health"}))
def test_guest_catalog_does_not_silently_accept_rejected_credentials(client, monkeypatch, path):
  from app.api.v1.dependencies import firebase_verifier

  def reject(_token):
    raise ApiError(code="AUTH_INVALID", message="Rejected credential.", status_code=401)

  monkeypatch.setattr(firebase_verifier, "verify", reject)
  assert client.get(path).status_code == 200
  assert client.get(path, headers={"Authorization": "Bearer rejected-token"}).status_code == 401


@pytest.mark.parametrize("operation", ["detail", "feedback", "metrics", "attempts", "finalize", "audio-list", "audio-upload"])
def test_all_session_operations_hide_other_users_resources(client, auth_headers, operation):
  created = client.post("/v1/sessions", headers=auth_headers, json={"mode": "training", "exercise_type": "warmup_pitch"})
  session_id = created.json()["session_id"]
  original = client.get(f"/v1/sessions/{session_id}", headers=auth_headers).json()
  path = f"/v1/sessions/{session_id}"
  method = "GET"
  payload = None
  if operation in {"metrics", "attempts", "finalize"}:
    path += f"/{operation}"
    method = "POST"
  if operation == "feedback":
    path += "/feedback"
  if operation.startswith("audio-"):
    path += "/audio-snippets"
  if operation == "audio-upload":
    method = "POST"
    payload = {"audio_base64": base64.b64encode(b"test-audio").decode(), "content_type": "audio/wav", "duration_sec": 1, "sample_rate_hz": 44100, "channel_count": 1}
  if operation == "metrics":
    payload = {"metrics": [{"session_id": session_id, "timestamp_ms": 1, "exercise_type": "warmup_pitch", "pitch_accuracy": 70, "timing_accuracy": 70, "breath_control": 70, "pitch_stability": 70, "vibrato_consistency": 70, "note_transition_smoothness": 70}]}
  if operation == "attempts":
    payload = {"attempt_index": 1, "difficulty": "beginner", "duration_sec": 30, "metric_summary": {"sample_count": 64, "pitch_accuracy": 70, "timing_accuracy": 70, "breath_control": 70, "pitch_stability": 70, "vibrato_consistency": 70, "note_transition_smoothness": 70}}
  response = client.request(method, path, headers={"Authorization": "Bearer dev_other-user"}, json=payload)
  assert response.status_code == 404, (operation, response.text)
  owner = client.get(f"/v1/sessions/{session_id}", headers=auth_headers).json()
  assert owner == original


def test_unknown_routes_and_methods_do_not_return_internal_errors(client):
  assert client.get("/v1/not-a-real-route").status_code == 404
  assert client.delete("/health").status_code == 405


def test_session_list_only_returns_the_callers_sessions(client, auth_headers):
  owner_id = client.post("/v1/sessions", headers=auth_headers, json={"mode": "training", "exercise_type": "warmup_pitch"}).json()["session_id"]
  other = {"Authorization": "Bearer dev_other-user"}
  other_id = client.post("/v1/sessions", headers=other, json={"mode": "training", "exercise_type": "warmup_pitch"}).json()["session_id"]
  for headers, wanted, excluded in [(auth_headers, owner_id, other_id), (other, other_id, owner_id)]:
    response = client.get("/v1/sessions?force_refresh=true", headers=headers)
    assert response.status_code == 200
    ids = {session["session_id"] for session in response.json()}
    assert wanted in ids
    assert excluded not in ids


def test_song_progress_returns_a_valid_empty_user_scoped_response(client, auth_headers):
  response = client.get("/v1/karaoke/progress", headers=auth_headers)
  assert response.status_code == 200
  assert response.json()["user_id"] == "test-user"
  assert response.json()["items"] == []
