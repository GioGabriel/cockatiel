"""Integration tests for profile endpoints."""
from fastapi.testclient import TestClient


class TestFetchProfile:
  def test_get_profile_returns_200(self, client: TestClient, auth_headers: dict) -> None:
    # First trigger user creation via auth/me
    client.get("/v1/auth/me", headers=auth_headers)
    resp = client.get("/v1/profile", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["uid"] == "test-user"
    assert data["access_tier"] == "registered"
    assert data["vocal_preferences"] is None

  def test_get_profile_401_without_auth(self, client: TestClient) -> None:
    resp = client.get("/v1/profile")
    assert resp.status_code == 401


class TestUpdatePreferences:
  def test_valid_preferences_returns_200(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    payload = {
      "vocal_range": "tenor",
      "preferred_categories": ["vocal_training", "breathing"],
      "training_goal": "pitch_improvement",
    }
    resp = client.put("/v1/profile/preferences", headers=auth_headers, json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["vocal_preferences"]["vocal_range"] == "tenor"
    assert data["vocal_preferences"]["preferred_categories"] == ["vocal_training", "breathing"]

  def test_invalid_vocal_range_returns_422(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    payload = {
      "vocal_range": "invalid",
      "preferred_categories": ["vocal_training"],
      "training_goal": "pitch_improvement",
    }
    resp = client.put("/v1/profile/preferences", headers=auth_headers, json=payload)
    assert resp.status_code == 422

  def test_too_many_categories_returns_422(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    payload = {
      "vocal_range": "tenor",
      "preferred_categories": ["vocal_training", "do_re_mi", "breathing", "extra"],
      "training_goal": "pitch_improvement",
    }
    resp = client.put("/v1/profile/preferences", headers=auth_headers, json=payload)
    assert resp.status_code == 422

  def test_extra_fields_rejected(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    payload = {
      "vocal_range": "tenor",
      "preferred_categories": ["vocal_training"],
      "training_goal": "pitch_improvement",
      "unknown_field": "bad",
    }
    resp = client.put("/v1/profile/preferences", headers=auth_headers, json=payload)
    assert resp.status_code == 422


class TestUpgradeTier:
  def test_upgrade_to_premium_returns_200(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    resp = client.post("/v1/profile/tier/upgrade", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["access_tier"] == "premium"
    assert data["premium_expires_at"] is not None
    assert data["premium_expires_at"] > 0

  def test_upgrade_is_idempotent(self, client: TestClient, auth_headers: dict) -> None:
    client.get("/v1/auth/me", headers=auth_headers)
    client.post("/v1/profile/tier/upgrade", headers=auth_headers)
    resp = client.post("/v1/profile/tier/upgrade", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["access_tier"] == "premium"
