import logging
from dataclasses import dataclass
from functools import lru_cache

from app.core.config import settings
from app.repositories.base import AnalyticsRepository, AudioSnippetRepository, SessionRepository, UserRepository
from app.repositories.memory.analytics_repository import InMemoryAnalyticsRepository
from app.repositories.memory.audio_snippets_repository import InMemoryAudioSnippetRepository
from app.repositories.memory.sessions_repository import InMemorySessionRepository
from app.repositories.memory.users_repository import InMemoryUserRepository

logger = logging.getLogger("vocal-coach-api.repositories")


def _is_production() -> bool:
  return settings.app_env.strip().lower() in {"prod", "production", "staging"}


@dataclass(frozen=True)
class RepositoryBundle:
  users: UserRepository
  sessions: SessionRepository
  analytics: AnalyticsRepository
  audio_snippets: AudioSnippetRepository
  backend: str


@lru_cache(maxsize=1)
def get_repository_bundle() -> RepositoryBundle:
  if _is_production() and not settings.firestore_enabled:
    raise RuntimeError("Persistent storage is required in production.")

  if settings.firestore_enabled:
    try:
      from app.repositories.firestore.client import build_firestore_client
      from app.repositories.firestore.analytics_repository import FirestoreAnalyticsRepository
      from app.repositories.firestore.audio_snippets_repository import FirestoreAudioSnippetRepository
      from app.repositories.firestore.sessions_repository import FirestoreSessionRepository
      from app.repositories.firestore.users_repository import FirestoreUserRepository

      db = build_firestore_client()
      return RepositoryBundle(
        users=FirestoreUserRepository(db),
        sessions=FirestoreSessionRepository(db),
        analytics=FirestoreAnalyticsRepository(db),
        audio_snippets=FirestoreAudioSnippetRepository(db),
        backend="firestore",
      )
    except Exception as exc:  # pragma: no cover - network/credentials/optional pkg
      if _is_production():
        logger.error("Persistent repository unavailable error_type=%s", type(exc).__name__)
        raise RuntimeError("Persistent storage is unavailable in production.") from exc
      logger.warning("Falling back to in-memory repository error_type=%s", type(exc).__name__)

  return RepositoryBundle(
    users=InMemoryUserRepository(),
    sessions=InMemorySessionRepository(),
    analytics=InMemoryAnalyticsRepository(),
    audio_snippets=InMemoryAudioSnippetRepository(),
    backend="memory",
  )


def get_user_repository() -> UserRepository:
  return get_repository_bundle().users


def get_session_repository() -> SessionRepository:
  return get_repository_bundle().sessions


def get_analytics_repository() -> AnalyticsRepository:
  return get_repository_bundle().analytics


def get_audio_snippet_repository() -> AudioSnippetRepository:
  return get_repository_bundle().audio_snippets


def reset_repository_bundle() -> None:
  get_repository_bundle.cache_clear()
