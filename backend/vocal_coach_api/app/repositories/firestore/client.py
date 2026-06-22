from typing import Any

from app.core.config import settings


def build_firestore_client() -> Any:
  try:
    from google.cloud import firestore
  except ImportError as exc:  # pragma: no cover - depends on optional package
    raise RuntimeError("google-cloud-firestore is not installed.") from exc

  if settings.firestore_project_id:
    return firestore.Client(project=settings.firestore_project_id)
  return firestore.Client()
