import logging
from functools import lru_cache

from app.core.config import settings
from app.storage.audio_snippets.adapters.local_file.storage import LocalAudioSnippetStorage

logger = logging.getLogger("vocal-coach-api.audio-snippets")


class NoopAudioSnippetStorage:
  backend_name = "metadata-only"

  def save(
    self,
    *,
    snippet_id: str,
    user_id: str,
    session_id: str,
    data: bytes,
    extension: str,
  ) -> dict[str, str | int]:
    _ = (snippet_id, user_id, session_id, extension)
    return {
      "storage_backend": self.backend_name,
      "storage_path": f"memory://{snippet_id}",
      "size_bytes": len(data),
    }

  def delete(self, storage_path: str) -> None:
    _ = storage_path


@lru_cache(maxsize=1)
def get_audio_snippet_storage():
  backend = (settings.audio_snippet_storage_backend or "local").strip().lower()
  if backend in {"none", "metadata-only", "memory"}:
    logger.info("audio_snippet_storage backend=metadata-only")
    return NoopAudioSnippetStorage()

  if settings.firestore_enabled or backend in {"firestore", "firebase", "firebase_storage", "gcs"}:
    try:
      from app.repositories.firestore.client import build_firestore_client
      from app.storage.audio_snippets.adapters.firestore.storage import FirestoreAudioSnippetStorage
      logger.info("audio_snippet_storage backend=firestore")
      return FirestoreAudioSnippetStorage(build_firestore_client())
    except Exception as exc:
      logger.warning("audio_snippet_storage firestore init failed, falling back to local: %s", exc)

  if backend in {"local", "filesystem", "fs"}:
    logger.info("audio_snippet_storage backend=local root=%s", settings.audio_snippet_local_dir)
    return LocalAudioSnippetStorage(settings.audio_snippet_local_dir)

  logger.warning("audio_snippet_storage backend=%s unsupported, defaulting to local", backend)
  return LocalAudioSnippetStorage(settings.audio_snippet_local_dir)


def reset_audio_snippet_storage() -> None:
  get_audio_snippet_storage.cache_clear()
