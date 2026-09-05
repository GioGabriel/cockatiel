from dataclasses import replace

import pytest


def test_production_does_not_fallback_to_local_audio_storage(monkeypatch):
  from app.repositories.firestore import client as firestore_client
  from app.storage.audio_snippets import service as storage_service

  production_settings = replace(
    storage_service.settings,
    app_env="production",
    firestore_enabled=True,
    audio_snippet_storage_backend="firestore",
  )
  monkeypatch.setattr(storage_service, "settings", production_settings)

  def unavailable_firestore():
    raise RuntimeError("firestore unavailable")

  monkeypatch.setattr(firestore_client, "build_firestore_client", unavailable_firestore)
  storage_service.reset_audio_snippet_storage()

  with pytest.raises(RuntimeError, match="Audio snippet storage is unavailable in production"):
    storage_service.get_audio_snippet_storage()


def test_production_rejects_local_audio_storage(monkeypatch):
  from app.storage.audio_snippets import service as storage_service

  production_settings = replace(
    storage_service.settings,
    app_env="production",
    firestore_enabled=False,
    audio_snippet_storage_backend="local",
  )
  monkeypatch.setattr(storage_service, "settings", production_settings)
  storage_service.reset_audio_snippet_storage()

  with pytest.raises(RuntimeError, match="Local audio storage is not permitted in production"):
    storage_service.get_audio_snippet_storage()
