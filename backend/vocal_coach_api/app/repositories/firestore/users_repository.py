from datetime import datetime, timezone
from typing import Any


class FirestoreUserRepository:
  collection_name = "users"

  def __init__(self, db: Any) -> None:
    self._db = db

  def upsert(self, identity: dict[str, Any]) -> dict[str, Any]:
    uid = identity["uid"]
    now = datetime.now(timezone.utc).isoformat()
    doc_ref = self._db.collection(self.collection_name).document(uid)
    doc_ref.set(
      {
        "uid": uid,
        "email": identity.get("email", ""),
        "name": identity.get("name", ""),
        "updated_at": now,
      },
      merge=True,
    )
    snap = doc_ref.get()
    return snap.to_dict() or {"uid": uid, "email": "", "name": ""}

  def get(self, uid: str) -> dict[str, Any] | None:
    doc_ref = self._db.collection(self.collection_name).document(uid)
    snap = doc_ref.get()
    if not snap.exists:
      return None
    return snap.to_dict()

  def update(self, uid: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    doc_ref = self._db.collection(self.collection_name).document(uid)
    snap = doc_ref.get()
    if not snap.exists:
      return None
    now = datetime.now(timezone.utc).isoformat()
    updates["updated_at"] = now
    doc_ref.update(updates)
    snap = doc_ref.get()
    return snap.to_dict()
