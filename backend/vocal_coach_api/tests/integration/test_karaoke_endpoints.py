"""Integration tests for karaoke catalog endpoints."""
from fastapi.testclient import TestClient


class TestFetchKaraokeCatalog:
  def test_catalog_returns_200_with_auth(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/karaoke/catalog", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["module_id"] == "karaoke"
    assert len(data["categories"]) >= 3

  def test_catalog_401_without_auth(self, client: TestClient) -> None:
    resp = client.get("/v1/karaoke/catalog")
    assert resp.status_code == 401

  def test_catalog_categories_have_distinct_labels(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/karaoke/catalog", headers=auth_headers)
    data = resp.json()
    labels = [c["style_label"] for c in data["categories"]]
    assert len(labels) == len(set(labels))

  def test_each_category_has_drills(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/karaoke/catalog", headers=auth_headers)
    for cat in resp.json()["categories"]:
      assert len(cat["drills"]) >= 1


class TestFetchKaraokeCatalogPreview:
  def test_preview_accessible_without_auth(self, client: TestClient) -> None:
    resp = client.get("/v1/karaoke/catalog/preview")
    assert resp.status_code == 200
    data = resp.json()
    assert "category_count" in data
    assert "total_drills" in data
    assert data["category_count"] >= 3

  def test_preview_with_auth(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/karaoke/catalog/preview", headers=auth_headers)
    assert resp.status_code == 200


class TestFetchKaraokeDrill:
  def test_valid_drill_id_returns_200(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/karaoke/catalog/pop_breath_control_1", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["drill_id"] == "pop_breath_control_1"
    assert "melody_reference" in data
    assert len(data["melody_reference"]) >= 1

  def test_unknown_drill_id_returns_404(self, client: TestClient, auth_headers: dict) -> None:
    resp = client.get("/v1/karaoke/catalog/nonexistent_drill", headers=auth_headers)
    assert resp.status_code == 404

  def test_drill_401_without_auth(self, client: TestClient) -> None:
    resp = client.get("/v1/karaoke/catalog/pop_breath_control_1")
    assert resp.status_code == 401
