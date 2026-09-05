"""Configuration tests that never print or require real provider credentials."""

import pytest


def test_openrouter_keys_accept_singular_or_plural_environment_names(monkeypatch):
  from app.core import config

  monkeypatch.delenv("OPENROUTER_API_KEYS", raising=False)
  monkeypatch.setenv("OPENROUTER_API_KEY", "singular-test-key")
  assert config._openrouter_api_keys_from_env() == ["singular-test-key"]

  monkeypatch.setenv("OPENROUTER_API_KEYS", "first-test-key, second-test-key")
  assert config._openrouter_api_keys_from_env() == ["first-test-key", "second-test-key"]


def test_openrouter_key_reader_prefers_plural_for_safe_migration(monkeypatch):
  from app.core import config

  monkeypatch.setenv("OPENROUTER_API_KEYS", "plural-test-key")
  monkeypatch.setenv("OPENROUTER_API_KEY", "singular-test-key")
  assert config._openrouter_api_keys_from_env() == ["plural-test-key"]


def test_numeric_configuration_uses_safe_bounds_and_defaults(monkeypatch):
  from app.core import config

  monkeypatch.setenv("AI_WORKER_MAX_RETRIES", "not-a-number")
  monkeypatch.setenv("OPENROUTER_TIMEOUT_S", "999")
  monkeypatch.setenv("OPENROUTER_TEMPERATURE", "-1")

  assert config._as_int("AI_WORKER_MAX_RETRIES", 5, minimum=0, maximum=20) == 5
  assert config._as_int("OPENROUTER_TIMEOUT_S", 20, minimum=1, maximum=60) == 60
  assert config._as_float("OPENROUTER_TEMPERATURE", 0.2, minimum=0.0, maximum=2.0) == 0.0


def test_production_auth_bypass_is_always_disabled(monkeypatch):
  from app.core import config

  monkeypatch.setenv("APP_ENV", "production")
  monkeypatch.setenv("AUTH_BYPASS", "true")

  assert config._auth_bypass_enabled() is False


def test_cors_localhost_default_is_disabled_for_production(monkeypatch):
  from app.core import config

  monkeypatch.setenv("APP_ENV", "production")

  assert config._allow_localhost_cors_by_default() is False


def test_cors_origin_reader_rejects_wildcards_and_non_origins(monkeypatch):
  from app.core import config

  monkeypatch.setenv(
    "CORS_ALLOWED_ORIGINS",
    "*, https://app.example.test/, javascript:alert(1), https://app.example.test/path",
  )

  assert config._cors_allowed_origins_from_env() == ["https://app.example.test"]


def test_production_repository_does_not_silently_use_memory_storage(monkeypatch):
  from types import SimpleNamespace

  from app.repositories import provider

  monkeypatch.setattr(
    provider,
    "settings",
    SimpleNamespace(firestore_enabled=False, app_env="production"),
  )
  provider.reset_repository_bundle()

  with pytest.raises(RuntimeError, match="Persistent storage is required"):
    provider.get_repository_bundle()
