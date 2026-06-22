from collections import defaultdict
from typing import Any


class InMemorySessionRepository:
  def __init__(self) -> None:
    self._sessions: dict[str, dict[str, Any]] = {}
    self._metrics_by_session: dict[str, list[dict[str, Any]]] = defaultdict(list)

  def create(self, record: dict[str, Any]) -> dict[str, Any]:
    session_id = record["session_id"]
    self._sessions[session_id] = record
    return dict(record)

  def get(self, session_id: str) -> dict[str, Any] | None:
    session = self._sessions.get(session_id)
    return dict(session) if session else None

  def update(self, session_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    session = self._sessions.get(session_id)
    if not session:
      return None
    session.update(updates)
    self._sessions[session_id] = session
    return dict(session)

  def append_metrics(self, session_id: str, metrics: list[dict[str, Any]]) -> int:
    self._metrics_by_session[session_id].extend(metrics)
    return len(metrics)

  def list_metrics(self, session_id: str) -> list[dict[str, Any]]:
    metrics = self._metrics_by_session.get(session_id, [])
    return [dict(item) for item in metrics]

  def list_by_user(self, user_id: str) -> list[dict[str, Any]]:
    sessions = [dict(item) for item in self._sessions.values() if item.get("user_id") == user_id]
    return sorted(
      sessions,
      key=lambda item: int(item.get("completed_at") or item.get("created_at") or 0),
      reverse=True,
    )
