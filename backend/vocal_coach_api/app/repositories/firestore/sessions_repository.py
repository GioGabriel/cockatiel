from typing import Any


class FirestoreSessionRepository:
  collection_name = "training_sessions"
  metric_subcollection = "metric_frames"

  def __init__(self, db: Any) -> None:
    self._db = db

  def _doc_ref(self, session_id: str):
    return self._db.collection(self.collection_name).document(session_id)

  def create(self, record: dict[str, Any]) -> dict[str, Any]:
    self._doc_ref(record["session_id"]).set(record)
    return dict(record)

  def get(self, session_id: str) -> dict[str, Any] | None:
    snap = self._doc_ref(session_id).get()
    if not snap.exists:
      return None
    return snap.to_dict()

  def update(self, session_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    doc_ref = self._doc_ref(session_id)
    snap = doc_ref.get()
    if not snap.exists:
      return None
    doc_ref.set(updates, merge=True)
    return doc_ref.get().to_dict()

  def append_metrics(self, session_id: str, metrics: list[dict[str, Any]]) -> int:
    metrics_ref = self._doc_ref(session_id).collection(self.metric_subcollection)
    for metric in metrics:
      metrics_ref.add(metric)
    return len(metrics)

  def list_metrics(self, session_id: str) -> list[dict[str, Any]]:
    stream = self._doc_ref(session_id).collection(self.metric_subcollection).stream()
    items = [doc.to_dict() for doc in stream]
    return sorted(items, key=lambda item: int(item.get("timestamp_ms", 0)))

  def list_by_user(self, user_id: str) -> list[dict[str, Any]]:
    stream = self._db.collection(self.collection_name).where("user_id", "==", user_id).stream()
    sessions = [doc.to_dict() for doc in stream]
    return sorted(
      sessions,
      key=lambda item: int(item.get("completed_at") or item.get("created_at") or 0),
      reverse=True,
    )
