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


def test_openrouter_client_parses_valid_json_and_records_model(monkeypatch):
  from app.ai_engine.providers import openrouter_client

  monkeypatch.setattr(
    openrouter_client,
    "urlopen",
    lambda _request, timeout: _Response({
      "choices": [{"message": {"content": '{"summary":"Keep going."}'}}],
    }),
  )

  client = openrouter_client.OpenRouterClient(
    api_keys=["test-key"],
    model="test/model",
    timeout_s=5,
    temperature=0.2,
    fallback_models=[],
  )

  payload, latency_ms = client.generate_json(system_prompt="system", user_prompt="user")

  assert payload == {"summary": "Keep going."}
  assert client.model == "test/model"
  assert latency_ms >= 0


def test_openrouter_client_does_not_retry_non_retryable_auth_failure(monkeypatch):
  from app.ai_engine.providers import openrouter_client

  calls = 0

  def fail_with_auth_error(_request, timeout):
    nonlocal calls
    calls += 1
    raise HTTPError("https://openrouter.ai", 401, "Unauthorized", {}, None)

  monkeypatch.setattr(openrouter_client, "urlopen", fail_with_auth_error)
  monkeypatch.setattr(openrouter_client.time, "sleep", lambda _seconds: None)

  client = openrouter_client.OpenRouterClient(
    api_keys=["first-key", "second-key"],
    model="test/model",
    timeout_s=5,
    temperature=0.2,
    fallback_models=[],
  )

  with pytest.raises(ValueError, match="HTTP status 401"):
    client.generate_json(system_prompt="system", user_prompt="user")

  assert calls == 2


def test_openrouter_client_fails_closed_without_keys():
  from app.ai_engine.providers.openrouter_client import OpenRouterClient

  client = OpenRouterClient(
    api_keys=[],
    model="test/model",
    timeout_s=5,
    temperature=0.2,
  )

  with pytest.raises(ValueError, match="No OpenRouter API keys configured"):
    client.generate_json(system_prompt="system", user_prompt="user")
