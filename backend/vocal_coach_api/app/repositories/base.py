from typing import Any, Protocol


class UserRepository(Protocol):
  def upsert(self, identity: dict[str, Any]) -> dict[str, Any]:
    ...

  def get(self, uid: str) -> dict[str, Any] | None:
    ...

  def update(self, uid: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    ...


class SessionRepository(Protocol):
  def create(self, record: dict[str, Any]) -> dict[str, Any]:
    ...

  def get(self, session_id: str) -> dict[str, Any] | None:
    ...

  def update(self, session_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
    ...

  def append_metrics(self, session_id: str, metrics: list[dict[str, Any]]) -> int:
    ...

  def list_metrics(self, session_id: str) -> list[dict[str, Any]]:
    ...

  def list_by_user(self, user_id: str) -> list[dict[str, Any]]:
    ...


class AnalyticsRepository(Protocol):
  def get_dashboard(self, user_id: str) -> dict[str, Any] | None:
    ...

  def upsert_dashboard(self, user_id: str, dashboard: dict[str, Any]) -> dict[str, Any]:
    ...

  def get_daily_rollup(self, user_id: str, date_key: str) -> dict[str, Any] | None:
    ...

  def upsert_daily_rollup(self, user_id: str, date_key: str, rollup: dict[str, Any]) -> dict[str, Any]:
    ...

  def list_daily_rollups(self, user_id: str, since_date: str | None = None, until_date: str | None = None) -> list[dict[str, Any]]:
    ...


class AudioSnippetRepository(Protocol):
  def create(self, snippet: dict[str, Any]) -> dict[str, Any]:
    ...

  def get(self, snippet_id: str) -> dict[str, Any] | None:
    ...

  def list_by_session(self, user_id: str, session_id: str) -> list[dict[str, Any]]:
    ...

  def list_expired(self, expires_before_ms: int, user_id: str | None = None) -> list[dict[str, Any]]:
    ...

  def delete(self, snippet_id: str) -> bool:
    ...
