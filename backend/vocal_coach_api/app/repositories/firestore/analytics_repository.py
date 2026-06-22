from typing import Any


class FirestoreAnalyticsRepository:
  collection_name = "analytics"
  daily_rollups_subcollection = "daily_rollups"

  def __init__(self, db: Any) -> None:
    self._db = db

  def _doc_ref(self, user_id: str):
    return self._db.collection(self.collection_name).document(user_id)

  def _daily_rollups_ref(self, user_id: str):
    return self._doc_ref(user_id).collection(self.daily_rollups_subcollection)

  def get_dashboard(self, user_id: str) -> dict[str, Any] | None:
    snap = self._doc_ref(user_id).get()
    if not snap.exists:
      return None
    return snap.to_dict()

  def upsert_dashboard(self, user_id: str, dashboard: dict[str, Any]) -> dict[str, Any]:
    doc_ref = self._doc_ref(user_id)
    doc_ref.set(dashboard, merge=True)
    snap = doc_ref.get()
    return snap.to_dict() or dict(dashboard)

  def get_daily_rollup(self, user_id: str, date_key: str) -> dict[str, Any] | None:
    snap = self._daily_rollups_ref(user_id).document(date_key).get()
    if not snap.exists:
      return None
    return snap.to_dict()

  def upsert_daily_rollup(self, user_id: str, date_key: str, rollup: dict[str, Any]) -> dict[str, Any]:
    doc_ref = self._daily_rollups_ref(user_id).document(date_key)
    doc_ref.set(rollup, merge=True)
    snap = doc_ref.get()
    return snap.to_dict() or dict(rollup)

  def list_daily_rollups(self, user_id: str, since_date: str | None = None, until_date: str | None = None) -> list[dict[str, Any]]:
    query = self._daily_rollups_ref(user_id)
    if since_date:
      query = query.where("date", ">=", since_date)
    if until_date:
      query = query.where("date", "<=", until_date)
    stream = query.stream()
    items = [doc.to_dict() for doc in stream]
    return sorted(items, key=lambda item: str(item.get("date", "")))
