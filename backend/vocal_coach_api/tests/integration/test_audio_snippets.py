import base64


def _create_session(client, auth_headers) -> str:
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={"mode": "training", "exercise_type": "warmup_pitch"},
  )
  assert response.status_code == 201
  return response.json()["session_id"]


def _audio_payload(duration_sec: float = 4.0) -> dict[str, object]:
  encoded = base64.b64encode(b"test-audio-snippet").decode("ascii")
  return {
    "audio_base64": encoded,
    "content_type": "audio/wav",
    "duration_sec": duration_sec,
    "sample_rate_hz": 44100,
    "channel_count": 1,
  }


def test_audio_snippet_upload_and_list(client, auth_headers):
  session_id = _create_session(client, auth_headers)

  upload = client.post(
    f"/v1/sessions/{session_id}/audio-snippets",
    headers=auth_headers,
    json=_audio_payload(),
  )
  assert upload.status_code == 201
  upload_payload = upload.json()
  assert upload_payload["session_id"] == session_id
  assert upload_payload["storage_backend"] == "local"
  assert upload_payload["size_bytes"] > 0

  listed = client.get(f"/v1/sessions/{session_id}/audio-snippets", headers=auth_headers)
  assert listed.status_code == 200
  list_payload = listed.json()
  assert list_payload["session_id"] == session_id
  assert len(list_payload["snippets"]) == 1
  assert list_payload["snippets"][0]["snippet_id"] == upload_payload["snippet_id"]


def test_audio_snippet_rejects_excessive_duration(client, auth_headers):
  session_id = _create_session(client, auth_headers)

  response = client.post(
    f"/v1/sessions/{session_id}/audio-snippets",
    headers=auth_headers,
    json=_audio_payload(duration_sec=11.0),
  )

  assert response.status_code == 400
  assert response.json()["error"]["code"] == "AUDIO_SNIPPET_DURATION_EXCEEDED"


def test_audio_snippet_cleanup_removes_expired_entries(client, auth_headers):
  session_id = _create_session(client, auth_headers)

  upload = client.post(
    f"/v1/sessions/{session_id}/audio-snippets",
    headers=auth_headers,
    json=_audio_payload(),
  )
  assert upload.status_code == 201

  cleanup = client.post(
    "/v1/audio-snippets/cleanup",
    headers=auth_headers,
    params={"before_ms": 9999999999999},
  )
  assert cleanup.status_code == 200
  cleanup_payload = cleanup.json()
  assert cleanup_payload["checked_count"] >= 1
  assert cleanup_payload["removed_count"] >= 1

  listed = client.get(f"/v1/sessions/{session_id}/audio-snippets", headers=auth_headers)
  assert listed.status_code == 200
  assert listed.json()["snippets"] == []
