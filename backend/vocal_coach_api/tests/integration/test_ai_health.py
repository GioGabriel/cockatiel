from types import SimpleNamespace


def test_ai_health_disabled_when_ollama_not_enabled(client, auth_headers):
  response = client.get("/v1/ai/health", headers=auth_headers)
  assert response.status_code == 200
  payload = response.json()
  assert payload["status"] == "disabled"
  assert payload["ollama_enabled"] is False
  assert payload["reachable"] is False


def test_ai_health_reports_available_model(client, auth_headers, monkeypatch):
  from app.api.v1.endpoints import ai as ai_endpoint

  monkeypatch.setattr(
    ai_endpoint,
    "settings",
    SimpleNamespace(
      ollama_enabled=True,
      ai_async_enabled=True,
      ollama_base_url="http://localhost:11434",
      ollama_timeout_s=10,
      ollama_models=("llama3:latest", "qwen2.5:7b"),
    ),
  )
  monkeypatch.setattr(
    ai_endpoint,
    "list_ollama_models",
    lambda **kwargs: (["llama3:latest"], 9),
  )

  response = client.get("/v1/ai/health", headers=auth_headers)
  assert response.status_code == 200
  payload = response.json()
  assert payload["status"] == "ok"
  assert payload["reachable"] is True
  assert payload["latency_ms"] == 9
  assert payload["candidate_models"][0] == {"model": "llama3:latest", "available": True}
  assert payload["candidate_models"][1] == {"model": "qwen2.5:7b", "available": False}


def test_ai_health_reports_unreachable_ollama(client, auth_headers, monkeypatch):
  from app.api.v1.endpoints import ai as ai_endpoint

  monkeypatch.setattr(
    ai_endpoint,
    "settings",
    SimpleNamespace(
      ollama_enabled=True,
      ai_async_enabled=False,
      ollama_base_url="http://localhost:11434",
      ollama_timeout_s=10,
      ollama_models=("llama3:latest",),
    ),
  )

  def _raise_unavailable(**kwargs):
    raise ValueError("Ollama connection failed.")

  monkeypatch.setattr(ai_endpoint, "list_ollama_models", _raise_unavailable)

  response = client.get("/v1/ai/health", headers=auth_headers)
  assert response.status_code == 200
  payload = response.json()
  assert payload["status"] == "degraded"
  assert payload["reachable"] is False
  assert "unavailable" in payload["detail"].lower()
