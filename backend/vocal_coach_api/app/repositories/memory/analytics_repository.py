from typing import Any


class InMemoryAnalyticsRepository:
  def __init__(self) -> None:
    self._dashboards: dict[str, dict[str, Any]] = {}
    self._daily_rollups: dict[str, dict[str, dict[str, Any]]] = {}

  def get_dashboard(self, user_id: str) -> dict[str, Any] | None:
    dashboard = self._dashboards.get(user_id)
    return dict(dashboard) if dashboard else None

  def upsert_dashboard(self, user_id: str, dashboard: dict[str, Any]) -> dict[str, Any]:
    self._dashboards[user_id] = dict(dashboard)
    return dict(self._dashboards[user_id])

  def get_daily_rollup(self, user_id: str, date_key: str) -> dict[str, Any] | None:
    user_rollups = self._daily_rollups.get(user_id, {})
    rollup = user_rollups.get(date_key)
    return dict(rollup) if rollup else None

  def upsert_daily_rollup(self, user_id: str, date_key: str, rollup: dict[str, Any]) -> dict[str, Any]:
    user_rollups = self._daily_rollups.setdefault(user_id, {})
    user_rollups[date_key] = dict(rollup)
    return dict(user_rollups[date_key])

  def list_daily_rollups(self, user_id: str, since_date: str | None = None, until_date: str | None = None) -> list[dict[str, Any]]:
    user_rollups = self._daily_rollups.get(user_id, {})
    items = [dict(value) for _, value in sorted(user_rollups.items())]

    def _in_window(item: dict[str, Any]) -> bool:
      date_key = str(item.get("date", ""))
      if since_date and date_key < since_date:
        return False
      if until_date and date_key > until_date:
        return False
      return True

    return [item for item in items if _in_window(item)]
