import os
from dataclasses import dataclass, field


def _as_bool(name: str, default: bool) -> bool:
  raw = os.getenv(name, str(default)).strip().lower()
  return raw in {"1", "true", "yes", "on"}


def _as_csv(name: str, default: str = "") -> list[str]:
  raw = os.getenv(name, default)
  return [part.strip() for part in raw.split(",") if part.strip()]


def _default_ollama_models() -> tuple[str, ...]:
  explicit = _as_csv("OLLAMA_MODELS")
  if explicit:
    return tuple(explicit)
  single = os.getenv("OLLAMA_MODEL", "llama3.1:8b").strip()
  return (single,) if single else ("llama3.1:8b",)


@dataclass(frozen=True)
class Settings:
  app_name: str = os.getenv("APP_NAME", "Vocal Coach API")
  app_env: str = os.getenv("APP_ENV", "dev")
  api_prefix: str = os.getenv("API_PREFIX", "/v1")
  auth_bypass: bool = _as_bool("AUTH_BYPASS", True)

  ai_async_enabled: bool = _as_bool("AI_ASYNC_ENABLED", False)
  ai_worker_enabled: bool = _as_bool("AI_WORKER_ENABLED", True)
  ai_worker_poll_interval_ms: int = int(os.getenv("AI_WORKER_POLL_INTERVAL_MS", "300"))
  ai_worker_max_retries: int = int(os.getenv("AI_WORKER_MAX_RETRIES", "5"))

  audio_snippet_storage_backend: str = os.getenv("AUDIO_SNIPPET_STORAGE_BACKEND", "local")
  audio_snippet_local_dir: str = os.getenv("AUDIO_SNIPPET_LOCAL_DIR", "/tmp/vocal-coach/audio-snippets")
  audio_snippet_retention_days: int = int(os.getenv("AUDIO_SNIPPET_RETENTION_DAYS", "30"))
  audio_snippet_max_duration_sec: float = float(os.getenv("AUDIO_SNIPPET_MAX_DURATION_SEC", "10"))
  audio_snippet_max_bytes: int = int(os.getenv("AUDIO_SNIPPET_MAX_BYTES", str(2 * 1024 * 1024)))
  audio_snippet_cleanup_batch_limit: int = int(os.getenv("AUDIO_SNIPPET_CLEANUP_BATCH_LIMIT", "200"))
  audio_snippet_cleanup_worker_enabled: bool = _as_bool("AUDIO_SNIPPET_CLEANUP_WORKER_ENABLED", True)
  audio_snippet_cleanup_interval_sec: int = int(os.getenv("AUDIO_SNIPPET_CLEANUP_INTERVAL_SEC", "3600"))

  firestore_enabled: bool = _as_bool("FIRESTORE_ENABLED", False)
  firestore_project_id: str | None = os.getenv("FIRESTORE_PROJECT_ID")

  ollama_enabled: bool = _as_bool("OLLAMA_ENABLED", False)
  ollama_base_url: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
  ollama_model: str = os.getenv("OLLAMA_MODEL", "llama3.1:8b")
  ollama_models: tuple[str, ...] = field(default_factory=_default_ollama_models)
  ollama_timeout_s: int = int(os.getenv("OLLAMA_TIMEOUT_S", "180"))
  ollama_temperature: float = float(os.getenv("OLLAMA_TEMPERATURE", "0.2"))
  prompt_version: str = os.getenv("PROMPT_VERSION", "v1")

  openrouter_enabled: bool = _as_bool("OPENROUTER_ENABLED", False)
  openrouter_api_key: str = os.getenv("OPENROUTER_API_KEY", "")
  openrouter_model: str = os.getenv("OPENROUTER_MODEL", "meta-llama/llama-3.1-8b-instruct:free")
  openrouter_timeout_s: int = int(os.getenv("OPENROUTER_TIMEOUT_S", "60"))
  openrouter_temperature: float = float(os.getenv("OPENROUTER_TEMPERATURE", "0.2"))


settings = Settings()
