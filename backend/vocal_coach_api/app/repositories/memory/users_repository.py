from time import time
from typing import Any


class InMemoryUserRepository:
  def __init__(self) -> None:
    self._users: dict[str, dict[str, Any]] = {}

  def upsert(self, identity: dict[str, Any]) -> dict[str, Any]:
    uid = identity["uid"]
    now_ms = int(time() * 1000)
    existing = self._users.get(uid, {})
    user = {
      "uid": uid,
      "email": identity.get("email", existing.get("email", "")),
      "name": identity.get("name", existing.get("name", "")),
      "access_tier": existing.get("access_tier", "registered"),
      "vocal_preferences": existing.get("vocal_preferences", None),
      "premium_expires_at": existing.get("premium_expires_at", None),
      "created_at": existing.get("created_at", now_ms),
      "updated_at": now_ms,
    }
    self._users[uid] = user
    return user

  def get(self, uid: str) -> dict[str, Any] | None:
    return self._users.get(uid)

  def update(self, uid: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    user = self._users.get(uid)
    if user is None:
      return None
    now_ms = int(time() * 1000)
    user.update(updates)
    user["updated_at"] = now_ms
    self._users[uid] = user
    return user
