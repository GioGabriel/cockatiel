from pathlib import Path

import yaml

from app.main import app


def test_checked_in_openapi_covers_the_live_route_surface() -> None:
  repository_root = Path(__file__).resolve().parents[4]
  contract_path = repository_root / "contracts/api/openapi/vocal_coach_v1.yaml"
  contract = yaml.safe_load(contract_path.read_text(encoding="utf-8"))

  actual_paths = {
    path: {method for method in operation if method in {"get", "post", "put", "patch", "delete"}}
    for path, operation in app.openapi()["paths"].items()
  }
  contract_paths = {
    path: {method for method in operation if method in {"get", "post", "put", "patch", "delete"}}
    for path, operation in contract["paths"].items()
  }

  assert contract_paths == actual_paths


def test_openapi_contract_has_a_bearer_security_scheme() -> None:
  repository_root = Path(__file__).resolve().parents[4]
  contract_path = repository_root / "contracts/api/openapi/vocal_coach_v1.yaml"
  contract = yaml.safe_load(contract_path.read_text(encoding="utf-8"))

  bearer = contract["components"]["securitySchemes"]["bearerAuth"]
  assert bearer == {"type": "http", "scheme": "bearer"}
