from types import SimpleNamespace


def _settings(*, enabled: bool, keys: list[str]):
  return SimpleNamespace(
    openrouter_enabled=enabled,
    openrouter_api_keys=keys,
    ai_async_enabled=False,
    openrouter_model="test-model",
    openrouter_timeout_s=5,
  )


def test_ai_health_reports_disabled_without_claiming_reachability(client, auth_headers, monkeypatch):
  from app.api.v1.endpoints import ai as ai_endpoint

  monkeypatch.setattr(ai_endpoint, "settings", _settings(enabled=False, keys=[]))
  response = client.get("/v1/ai/health", headers=auth_headers)

  assert response.status_code == 200
  assert response.json()["status"] == "disabled"
  assert response.json()["configured"] is False
  assert response.json()["reachability"] == "disabled"
  assert response.json()["reachable"] is False


def test_ai_health_reports_configured_but_unverified_provider(client, auth_headers, monkeypatch):
  from app.api.v1.endpoints import ai as ai_endpoint

  monkeypatch.setattr(ai_endpoint, "settings", _settings(enabled=True, keys=["redacted-test-key"]))
  response = client.get("/v1/ai/health", headers=auth_headers)

  assert response.status_code == 200
  assert response.json()["status"] == "configured"
  assert response.json()["configured"] is True
  assert response.json()["reachability"] == "unknown"
  assert response.json()["reachable"] is False
