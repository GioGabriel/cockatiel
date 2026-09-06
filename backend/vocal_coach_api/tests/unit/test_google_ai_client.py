import json
from urllib.error import HTTPError

import pytest


class _Response:
  def __init__(self, payload: dict):
    self._payload = json.dumps(payload).encode()

  def __enter__(self):
    return self

  def __exit__(self, *_args):
    return False

  def read(self):
    return self._payload


def _gemini_response(summary: str = "Keep going.") -> dict:
  return {
    "candidates": [{
      "content": {
        "parts": [{"text": json.dumps({"summary": summary})}],
      },
    }],
  }


def test_google_ai_client_parses_structured_json_and_uses_google_auth_header(monkeypatch):
  from app.ai_engine.providers import google_ai_client

  requests = []

  def fake_urlopen(request, timeout):
    requests.append((request, timeout))
    return _Response(_gemini_response())

  monkeypatch.setattr(google_ai_client, "urlopen", fake_urlopen)

  client = google_ai_client.GoogleAiStudioClient(
    api_keys=["test-key"],
    model="gemini-test-model",
    timeout_s=5,
    temperature=0.2,
    fallback_models=[],
  )

  payload, latency_ms = client.generate_json(system_prompt="system", user_prompt="user")

  assert payload == {"summary": "Keep going."}
  assert client.model == "gemini-test-model"
  assert latency_ms >= 0
  request, timeout = requests[0]
  assert request.full_url.endswith("/models/gemini-test-model:generateContent")
  assert request.get_header("X-goog-api-key") == "test-key"
  assert request.get_header("Authorization") is None
  assert timeout <= 5
  body = json.loads(request.data)
  assert body["generationConfig"]["responseMimeType"] == "application/json"
  assert body["generationConfig"]["responseSchema"]["required"] == ["summary"]


def test_google_ai_client_rotates_to_next_key_after_rate_limit(monkeypatch):
  from app.ai_engine.providers import google_ai_client

  seen_keys = []

  def fail_first_key(request, timeout):
    key = request.get_header("X-goog-api-key")
    seen_keys.append(key)
    if key == "first-key":
      raise HTTPError(request.full_url, 429, "Rate limited", {}, None)
    return _Response(_gemini_response("Second key worked."))

  monkeypatch.setattr(google_ai_client, "urlopen", fail_first_key)
  monkeypatch.setattr(google_ai_client.time, "sleep", lambda _seconds: None)

  client = google_ai_client.GoogleAiStudioClient(
    api_keys=["first-key", "second-key"],
    model="gemini-test-model",
    timeout_s=5,
    temperature=0.2,
    fallback_models=[],
  )

  payload, _ = client.generate_json(system_prompt="system", user_prompt="user")

  assert payload == {"summary": "Second key worked."}
  assert seen_keys == ["first-key", "first-key", "second-key"]


def test_google_ai_client_does_not_retry_non_retryable_auth_failure(monkeypatch):
  from app.ai_engine.providers import google_ai_client

  calls = 0

  def fail_with_auth_error(request, timeout):
    nonlocal calls
    calls += 1
    raise HTTPError(request.full_url, 403, "Forbidden", {}, None)

  monkeypatch.setattr(google_ai_client, "urlopen", fail_with_auth_error)

  client = google_ai_client.GoogleAiStudioClient(
    api_keys=["first-key", "second-key"],
    model="gemini-test-model",
    timeout_s=5,
    temperature=0.2,
    fallback_models=[],
  )

  with pytest.raises(ValueError, match="HTTP status 403"):
    client.generate_json(system_prompt="system", user_prompt="user")

  assert calls == 2


def test_google_ai_client_rejects_empty_provider_payload(monkeypatch):
  from app.ai_engine.providers import google_ai_client

  monkeypatch.setattr(
    google_ai_client,
    "urlopen",
    lambda _request, timeout: _Response({"candidates": []}),
  )

  client = google_ai_client.GoogleAiStudioClient(
    api_keys=["test-key"],
    model="gemini-test-model",
    timeout_s=5,
    temperature=0.2,
    fallback_models=[],
  )

  with pytest.raises(ValueError, match="no candidates"):
    client.generate_json(system_prompt="system", user_prompt="user")


def test_google_ai_client_fails_closed_without_keys():
  from app.ai_engine.providers.google_ai_client import GoogleAiStudioClient

  client = GoogleAiStudioClient(
    api_keys=[],
    model="gemini-test-model",
    timeout_s=5,
    temperature=0.2,
  )

  with pytest.raises(ValueError, match="No Google AI API keys configured"):
    client.generate_json(system_prompt="system", user_prompt="user")
