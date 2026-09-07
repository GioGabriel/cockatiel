from typing import Any

try:
  from google.api_core.exceptions import NotFound
except ImportError:  # pragma: no cover - Firestore is an optional local dependency
  class NotFound(Exception):
    pass

from app.repositories.cache.ttl_singleflight import BoundedTtlSingleFlightCache


_SESSION_LIST_CACHE_TTL_SEC = 30.0
_SESSION_LIST_CACHE_MAX_ENTRIES = 256


class FirestoreSessionRepository:
  collection_name = "training_sessions"
  metric_subcollection = "metric_frames"

  def __init__(self, db: Any) -> None:
    self._db = db
    # Several endpoints need the same user's session list. Keep a short-lived
    # process-local copy so dashboard, recommendations, history, and AI status
    # requests do not each scan every session document. Writes invalidate this
    # cache; the TTL also limits staleness when another process writes data.
    self._session_list_cache = BoundedTtlSingleFlightCache[
      str,
      list[dict[str, Any]],
    ](
      ttl_seconds=_SESSION_LIST_CACHE_TTL_SEC,
      max_entries=_SESSION_LIST_CACHE_MAX_ENTRIES,
      name="session_list",
    )

  def _doc_ref(self, session_id: str):
    return self._db.collection(self.collection_name).document(session_id)

  def create(self, record: dict[str, Any]) -> dict[str, Any]:
    self._doc_ref(record["session_id"]).set(record)
    self._session_list_cache.invalidate_all()
    return dict(record)

  def get(self, session_id: str) -> dict[str, Any] | None:
    snap = self._doc_ref(session_id).get()
    if not snap.exists:
      return None
    return snap.to_dict()

  def update(self, session_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    doc_ref = self._doc_ref(session_id)
    try:
      # update() is atomic and avoids the old read-before/read-after sequence.
      # Callers already hold or construct the session context they need.
      doc_ref.update(updates)
    except NotFound:
      return None
    self._session_list_cache.invalidate_all()
    return dict(updates)

  def append_metrics(self, session_id: str, metrics: list[dict[str, Any]]) -> int:
    metrics_ref = self._doc_ref(session_id).collection(self.metric_subcollection)
    for metric in metrics:
      metrics_ref.add(metric)
    return len(metrics)

  def list_metrics(self, session_id: str) -> list[dict[str, Any]]:
    stream = self._doc_ref(session_id).collection(self.metric_subcollection).stream()
    items = [doc.to_dict() for doc in stream]
    return sorted(items, key=lambda item: int(item.get("timestamp_ms", 0)))

  def list_by_user(self, user_id: str, *, force_refresh: bool = False) -> list[dict[str, Any]]:
    def load() -> list[dict[str, Any]]:
      stream = self._db.collection(self.collection_name).where("user_id", "==", user_id).stream()
      sessions = [doc.to_dict() for doc in stream]
      return sorted(
        sessions,
        key=lambda item: int(item.get("completed_at") or item.get("created_at") or 0),
        reverse=True,
      )

    if force_refresh:
      # Explicit user refreshes must observe a post-write document scan. The
      # cache utility's generation token prevents an older in-flight scan from
      # satisfying this request after invalidation.
      self._session_list_cache.invalidate(user_id)
    return self._session_list_cache.get_or_load(user_id, load)
