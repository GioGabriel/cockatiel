"""Smoke tests verifying all six thesis modules have functional endpoints."""
from fastapi.testclient import TestClient


class TestThesisModuleEndpoints:
  """Verify each thesis module has at least one responsive endpoint."""

  def test_account_module_responds(self, client: TestClient, auth_headers: dict) -> None:
    """Account Module: GET /v1/auth/me."""
    resp = client.get("/v1/auth/me", headers=auth_headers)
    assert resp.status_code == 200

  def test_dashboard_module_responds(self, client: TestClient, auth_headers: dict) -> None:
    """Dashboard Module: GET /v1/analytics/dashboard."""
    resp = client.get("/v1/analytics/dashboard", headers=auth_headers)
    assert resp.status_code == 200

  def test_voice_room_module_responds(self, client: TestClient, auth_headers: dict) -> None:
    """Voice Room Module: POST /v1/sessions (training mode)."""
    payload = {"mode": "training", "exercise_type": "resonance_placement"}
    resp = client.post("/v1/sessions", headers=auth_headers, json=payload)
    assert resp.status_code == 201

  def test_coaching_module_responds(self, client: TestClient, auth_headers: dict) -> None:
    """Coaching/Tutorial Module: GET /v1/training/catalog."""
    resp = client.get("/v1/training/catalog", headers=auth_headers)
    assert resp.status_code == 200

  def test_karaoke_module_responds(self, client: TestClient, auth_headers: dict) -> None:
    """Karaoke Module: GET /v1/karaoke/catalog."""
    resp = client.get("/v1/karaoke/catalog", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["categories"]) >= 3

  def test_progress_module_responds(self, client: TestClient, auth_headers: dict) -> None:
    """Progress Tracking Module: GET /v1/training/progress."""
    resp = client.get("/v1/training/progress", headers=auth_headers)
    assert resp.status_code == 200


class TestSprint11Exclusion:
  """Verify no Sprint 11 artifacts accessible via API."""

  def test_training_catalog_has_only_thesis_categories(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/training/catalog", headers=auth_headers)
    data = resp.json()
    valid_categories = {"vocal_training", "do_re_mi", "breathing"}
    actual_categories = {c["category_id"] for c in data["categories"]}
    assert actual_categories == valid_categories

  def test_no_diction_endpoints(self, client: TestClient, auth_headers: dict) -> None:
    """Ensure no diction/speech endpoints exist."""
    for path in ["/v1/speech", "/v1/diction", "/v1/pronunciation"]:
      resp = client.get(path, headers=auth_headers)
      assert resp.status_code == 404 or resp.status_code == 405


class TestProfileAndKaraokeEndpoints:
  """Verify new endpoints function correctly."""

  def test_profile_endpoint_responds(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    resp = client.get("/v1/profile", headers=auth_headers)
    assert resp.status_code == 200
    assert "access_tier" in resp.json()

  def test_karaoke_preview_accessible_without_auth(self, client: TestClient) -> None:
    resp = client.get("/v1/karaoke/catalog/preview")
    assert resp.status_code == 200
    assert resp.json()["category_count"] >= 3
