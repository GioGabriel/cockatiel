import asyncio
from types import SimpleNamespace

from starlette.requests import Request


def test_metrics_requires_configured_token_in_production(client, monkeypatch):
  from app import main

  monkeypatch.setattr(
    main,
    "settings",
    SimpleNamespace(app_env="production", metrics_access_token="metrics-test-token"),
  )

  response = client.get("/metrics")

  assert response.status_code == 404


def test_metrics_accepts_configured_token(client, monkeypatch):
  from app import main

  monkeypatch.setattr(
    main,
    "settings",
    SimpleNamespace(app_env="production", metrics_access_token="metrics-test-token"),
  )

  response = client.get("/metrics", headers={"X-Metrics-Token": "metrics-test-token"})

  assert response.status_code == 200
  assert isinstance(response.json(), dict)


def test_cors_configuration_never_combines_wildcard_origins_with_credentials():
  from app.main import app

  cors = next(middleware for middleware in app.user_middleware if middleware.cls.__name__ == "CORSMiddleware")

  assert cors.kwargs["allow_origins"] != ["*"]
  assert not (
    cors.kwargs["allow_origins"] == ["*"] and cors.kwargs["allow_credentials"] is True
  )


def test_local_chrome_origin_can_complete_cors_preflight(client):
  response = client.options(
    "/health",
    headers={
      "Origin": "http://localhost:4173",
      "Access-Control-Request-Method": "GET",
    },
  )

  assert response.status_code == 200
  assert response.headers["access-control-allow-origin"] == "http://localhost:4173"
  assert "GET" in response.headers["access-control-allow-methods"]


def test_request_timeout_returns_safe_traceable_504(monkeypatch):
  from app import main

  monkeypatch.setattr(main, "settings", SimpleNamespace(api_request_timeout_s=0.01))
  request = Request(
    {
      "type": "http",
      "method": "GET",
      "path": "/slow-test",
      "raw_path": b"/slow-test",
      "query_string": b"",
      "headers": [],
      "scheme": "http",
      "server": ("testserver", 80),
      "client": ("testclient", 1234),
      "root_path": "",
    }
  )

  async def slow_handler(_request):
    await asyncio.sleep(0.05)
    raise AssertionError("the handler should be cancelled by the timeout")

  response = asyncio.run(main.request_context_middleware(request, slow_handler))

  assert response.status_code == 504
  assert response.headers["x-request-id"]
  assert response.body is not None
  assert b"REQUEST_TIMEOUT" in response.body


def test_validation_errors_do_not_echo_request_values(client, auth_headers):
  response = client.put(
    "/v1/profile/preferences",
    headers=auth_headers,
    json={
      "vocal_range": "tenor",
      "preferred_categories": [],
      "training_goal": "pitch_accuracy",
      "secret": "do-not-echo-this-value",
    },
  )

  assert response.status_code == 422
  assert "do-not-echo-this-value" not in response.text
  assert all("input" not in item for item in response.json()["error"]["details"]["errors"])
