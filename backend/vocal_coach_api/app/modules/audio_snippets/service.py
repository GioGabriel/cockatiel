import base64
import binascii
from time import time
from uuid import uuid4

from app.api.v1.schemas import AudioSnippetCreateIn
from app.core.config import settings
from app.core.exceptions import ApiError
from app.modules.sessions.service import get_session
from app.repositories.provider import get_audio_snippet_repository
from app.storage.audio_snippets.service import get_audio_snippet_storage

_CONTENT_TYPE_TO_EXTENSION = {
  "audio/wav": "wav",
  "audio/x-wav": "wav",
  "audio/mpeg": "mp3",
  "audio/mp4": "m4a",
  "audio/aac": "aac",
  "audio/webm": "webm",
  "audio/ogg": "ogg",
}


def _decode_audio_base64(encoded: str) -> bytes:
  try:
    return base64.b64decode(encoded, validate=True)
  except (ValueError, binascii.Error) as exc:
    raise ApiError(
      code="AUDIO_SNIPPET_INVALID_BASE64",
      message="audio_base64 payload is invalid.",
      status_code=400,
    ) from exc


def _extension_for_content_type(content_type: str) -> str:
  normalized = content_type.strip().lower()
  return _CONTENT_TYPE_TO_EXTENSION.get(normalized, "bin")


def create_audio_snippet(user_id: str, session_id: str, payload: AudioSnippetCreateIn) -> dict[str, object]:
  get_session(session_id=session_id, user_id=user_id)

  if payload.duration_sec > settings.audio_snippet_max_duration_sec:
    raise ApiError(
      code="AUDIO_SNIPPET_DURATION_EXCEEDED",
      message="Audio snippet exceeds configured duration limit.",
      status_code=400,
      details={"max_duration_sec": settings.audio_snippet_max_duration_sec},
    )

  audio_bytes = _decode_audio_base64(payload.audio_base64)
  if len(audio_bytes) > settings.audio_snippet_max_bytes:
    raise ApiError(
      code="AUDIO_SNIPPET_TOO_LARGE",
      message="Audio snippet exceeds configured size limit.",
      status_code=413,
      details={"max_bytes": settings.audio_snippet_max_bytes},
    )

  snippet_id = str(uuid4())
  now_ms = int(time() * 1000)
  expires_at = now_ms + (settings.audio_snippet_retention_days * 24 * 60 * 60 * 1000)

  extension = _extension_for_content_type(payload.content_type)
  storage = get_audio_snippet_storage()
  storage_result = storage.save(
    snippet_id=snippet_id,
    user_id=user_id,
    session_id=session_id,
    data=audio_bytes,
    extension=extension,
  )

  snippet = {
    "snippet_id": snippet_id,
    "user_id": user_id,
    "session_id": session_id,
    "content_type": payload.content_type,
    "duration_sec": payload.duration_sec,
    "sample_rate_hz": payload.sample_rate_hz,
    "channel_count": payload.channel_count,
    "recorded_at_ms": payload.recorded_at_ms,
    "storage_backend": storage_result["storage_backend"],
    "storage_path": storage_result["storage_path"],
    "size_bytes": int(storage_result["size_bytes"]),
    "created_at": now_ms,
    "expires_at": expires_at,
  }

  repository = get_audio_snippet_repository()
  return repository.create(snippet)


def list_session_audio_snippets(user_id: str, session_id: str) -> list[dict[str, object]]:
  get_session(session_id=session_id, user_id=user_id)
  repository = get_audio_snippet_repository()
  return repository.list_by_session(user_id=user_id, session_id=session_id)


def cleanup_expired_audio_snippets(user_id: str | None = None, before_ms: int | None = None) -> dict[str, int]:
  cutoff_ms = int(before_ms if before_ms is not None else int(time() * 1000))
  repository = get_audio_snippet_repository()
  storage = get_audio_snippet_storage()

  expired = repository.list_expired(expires_before_ms=cutoff_ms, user_id=user_id)
  if settings.audio_snippet_cleanup_batch_limit > 0:
    expired = expired[: settings.audio_snippet_cleanup_batch_limit]

  checked_count = len(expired)
  removed_count = 0
  failed_count = 0

  for snippet in expired:
    snippet_id = str(snippet.get("snippet_id", ""))
    try:
      storage_path = str(snippet.get("storage_path", ""))
      if storage_path:
        storage.delete(storage_path)
      deleted = repository.delete(snippet_id)
      if deleted:
        removed_count += 1
      else:
        failed_count += 1
    except Exception:
      failed_count += 1

  return {
    "checked_count": checked_count,
    "removed_count": removed_count,
    "failed_count": failed_count,
    "cutoff_ms": cutoff_ms,
  }
