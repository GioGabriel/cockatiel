def test_karaoke_evaluation_rejects_unsupported_media_type(client, auth_headers):
  response = client.post(
    "/v1/karaoke/evaluate-tone",
    headers=auth_headers,
    files={"audio": ("sample.txt", b"not audio", "text/plain")},
    data={"pitch_score": "80", "rhythm_delay_ms": "0"},
  )

  assert response.status_code == 415
  assert response.json()["error"]["code"] == "AUDIO_TYPE_UNSUPPORTED"


def test_karaoke_evaluation_enforces_audio_size_limit(client, auth_headers, monkeypatch):
  from types import SimpleNamespace

  from app.api.v1.endpoints import karaoke as karaoke_endpoint

  monkeypatch.setattr(karaoke_endpoint, "settings", SimpleNamespace(audio_snippet_max_bytes=3))
  response = client.post(
    "/v1/karaoke/evaluate-tone",
    headers=auth_headers,
    files={"audio": ("sample.wav", b"1234", "audio/wav")},
    data={"pitch_score": "80", "rhythm_delay_ms": "0"},
  )

  assert response.status_code == 413
  assert response.json()["error"]["code"] == "AUDIO_TOO_LARGE"


def test_karaoke_evaluation_accepts_bounded_audio_upload(client, auth_headers):
  response = client.post(
    "/v1/karaoke/evaluate-tone",
    headers=auth_headers,
    files={"audio": ("sample.wav", b"not a real wav", "audio/wav")},
    data={"pitch_score": "80", "rhythm_delay_ms": "0"},
  )

  assert response.status_code == 200
  payload = response.json()
  assert payload["pitch_score"] == 80
  assert payload["tone_score"] is None
  assert payload["feedback_source"] == "pitch_timing_only"
