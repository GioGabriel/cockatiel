import os
from dataclasses import dataclass, field
from urllib.parse import urlsplit


def _as_bool(name: str, default: bool) -> bool:
  raw = os.getenv(name, str(default)).strip().lower()
  return raw in {"1", "true", "yes", "on"}


def _as_int(name: str, default: int, *, minimum: int | None = None, maximum: int | None = None) -> int:
  raw = os.getenv(name)
  try:
    value = int(raw) if raw is not None else default
  except ValueError:
    return default
  if minimum is not None:
    value = max(minimum, value)
  if maximum is not None:
    value = min(maximum, value)
  return value


def _as_float(
  name: str,
  default: float,
  *,
  minimum: float | None = None,
  maximum: float | None = None,
) -> float:
  raw = os.getenv(name)
  try:
    value = float(raw) if raw is not None else default
  except ValueError:
    return default
  if minimum is not None:
    value = max(minimum, value)
  if maximum is not None:
    value = min(maximum, value)
  return value


def _as_csv(name: str, default: str = "") -> list[str]:
  raw = os.getenv(name, default)
  return [part.strip() for part in raw.split(",") if part.strip()]


def _cors_allowed_origins_from_env() -> list[str]:
  """Return explicit browser origins; reject wildcard and URL-like values."""
  origins: list[str] = []
  for raw_origin in _as_csv("CORS_ALLOWED_ORIGINS"):
    if raw_origin == "*":
      continue
    parsed = urlsplit(raw_origin)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
      continue
    if parsed.path not in {"", "/"} or parsed.query or parsed.fragment or parsed.username or parsed.password:
      continue
    normalized = f"{parsed.scheme}://{parsed.netloc}"
    if normalized not in origins:
      origins.append(normalized)
  return origins


def _google_api_keys_from_env() -> list[str]:
  """Read comma-separated Google AI Studio keys without exposing their values."""
  plural = _as_csv("GOOGLE_API_KEYS", "")
  if plural:
    return plural
  return _as_csv("GOOGLE_API_KEY", "")


def _google_ai_enabled_default() -> bool:
  return bool(_google_api_keys_from_env())


def _google_ai_fallback_models_from_env() -> list[str]:
  return _as_csv("GOOGLE_AI_FALLBACK_MODELS", "gemini-2.5-flash")


def _auth_bypass_enabled() -> bool:
  """Allow the development shortcut only outside production environments."""
  app_env = os.getenv("APP_ENV", "dev").strip().lower()
  if app_env in {"prod", "production", "staging"}:
    return False
  return _as_bool("AUTH_BYPASS", False)


def _allow_localhost_cors_by_default() -> bool:
  app_env = os.getenv("APP_ENV", "dev").strip().lower()
  return app_env not in {"prod", "production", "staging"}


def _cors_allow_localhost_enabled() -> bool:
  """Never allow the local-origin shortcut in a production environment."""
  app_env = os.getenv("APP_ENV", "dev").strip().lower()
  if app_env in {"prod", "production", "staging"}:
    return False
  return _as_bool("CORS_ALLOW_LOCALHOST", _allow_localhost_cors_by_default())




@dataclass(frozen=True)
class Settings:
  app_name: str = os.getenv("APP_NAME", "Vocal Coach API")
  app_env: str = os.getenv("APP_ENV", "dev")
  api_prefix: str = os.getenv("API_PREFIX", "/v1")
  auth_bypass: bool = _auth_bypass_enabled()
  cors_allowed_origins: list[str] = field(default_factory=_cors_allowed_origins_from_env)
  cors_allow_localhost: bool = _cors_allow_localhost_enabled()
  metrics_access_token: str | None = os.getenv("METRICS_ACCESS_TOKEN") or None
  api_request_timeout_s: float = _as_float("API_REQUEST_TIMEOUT_S", 30.0, minimum=1.0, maximum=120.0)

  ai_async_enabled: bool = _as_bool("AI_ASYNC_ENABLED", False)
  ai_worker_enabled: bool = _as_bool("AI_WORKER_ENABLED", True)
  ai_worker_poll_interval_ms: int = _as_int("AI_WORKER_POLL_INTERVAL_MS", 300, minimum=50, maximum=60_000)
  ai_worker_max_retries: int = _as_int("AI_WORKER_MAX_RETRIES", 5, minimum=0, maximum=20)

  audio_snippet_storage_backend: str = os.getenv("AUDIO_SNIPPET_STORAGE_BACKEND", "local")
  audio_snippet_local_dir: str = os.getenv("AUDIO_SNIPPET_LOCAL_DIR", "/tmp/vocal-coach/audio-snippets")
  audio_snippet_retention_days: int = _as_int("AUDIO_SNIPPET_RETENTION_DAYS", 30, minimum=1, maximum=3650)
  audio_snippet_max_duration_sec: float = _as_float("AUDIO_SNIPPET_MAX_DURATION_SEC", 10.0, minimum=0.1, maximum=120.0)
  audio_snippet_max_bytes: int = _as_int("AUDIO_SNIPPET_MAX_BYTES", 2 * 1024 * 1024, minimum=1024, maximum=50 * 1024 * 1024)
  audio_snippet_cleanup_batch_limit: int = _as_int("AUDIO_SNIPPET_CLEANUP_BATCH_LIMIT", 200, minimum=1, maximum=10_000)
  audio_snippet_cleanup_worker_enabled: bool = _as_bool("AUDIO_SNIPPET_CLEANUP_WORKER_ENABLED", True)
  audio_snippet_cleanup_interval_sec: int = _as_int("AUDIO_SNIPPET_CLEANUP_INTERVAL_SEC", 3600, minimum=30, maximum=86_400)

  firestore_enabled: bool = _as_bool("FIRESTORE_ENABLED", False)
  firestore_project_id: str | None = os.getenv("FIRESTORE_PROJECT_ID")

  prompt_version: str = os.getenv("PROMPT_VERSION", "v1")

  google_ai_enabled: bool = _as_bool("GOOGLE_AI_ENABLED", _google_ai_enabled_default())
  google_api_keys: list[str] = field(default_factory=_google_api_keys_from_env)
  google_ai_model: str = os.getenv("GOOGLE_AI_MODEL", "gemini-2.5-flash-lite")
  google_ai_fallback_models: list[str] = field(default_factory=_google_ai_fallback_models_from_env)
  google_ai_timeout_s: int = _as_int("GOOGLE_AI_TIMEOUT_S", 20, minimum=1, maximum=60)
  google_ai_max_total_time_s: float = _as_float("GOOGLE_AI_MAX_TOTAL_TIME_S", 20.0, minimum=1.0, maximum=90.0)
  google_ai_temperature: float = _as_float("GOOGLE_AI_TEMPERATURE", 0.2, minimum=0.0, maximum=1.0)
  google_ai_max_output_tokens: int = _as_int("GOOGLE_AI_MAX_OUTPUT_TOKENS", 768, minimum=32, maximum=1024)


settings = Settings()


def validate_runtime_settings(config: object = settings) -> None:
  """Fail closed when required production services are not explicitly configured.

  Development may use the in-memory repository, local CORS, and local audio
  storage through an explicit local process configuration. Production must not
  silently start with any of those development-only paths.
  """
  app_env = str(getattr(config, "app_env", "dev")).strip().lower()
  if app_env not in {"prod", "production", "staging"}:
    return

  problems: list[str] = []
  if bool(getattr(config, "auth_bypass", False)):
    problems.append("AUTH_BYPASS must be false")
  if not bool(getattr(config, "firestore_enabled", False)):
    problems.append("FIRESTORE_ENABLED must be true")
  if not str(getattr(config, "firestore_project_id", "") or "").strip():
    problems.append("FIRESTORE_PROJECT_ID must be configured")
  if not list(getattr(config, "cors_allowed_origins", []) or []):
    problems.append("CORS_ALLOWED_ORIGINS must contain the deployed web origin")
  if bool(getattr(config, "cors_allow_localhost", False)):
    problems.append("localhost CORS must be disabled")

  audio_backend = str(getattr(config, "audio_snippet_storage_backend", "") or "").strip().lower()
  if audio_backend in {"local", "filesystem", "fs"}:
    problems.append("local audio storage is not permitted in production")

  if problems:
    raise RuntimeError("Production configuration is incomplete: " + "; ".join(problems) + ".")
