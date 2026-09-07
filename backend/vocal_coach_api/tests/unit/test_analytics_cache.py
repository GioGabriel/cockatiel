from copy import deepcopy
from time import time

from app.modules.analytics import service


class _FakeAnalyticsRepository:
  def __init__(self) -> None:
    self.dashboard: dict | None = None
    self.rollups: dict[str, dict] = {}
    self.get_dashboard_calls = 0
    self.list_rollup_calls = 0

  def get_dashboard(self, _user_id: str) -> dict | None:
    self.get_dashboard_calls += 1
    return deepcopy(self.dashboard)

  def upsert_dashboard(self, _user_id: str, dashboard: dict) -> dict:
    self.dashboard = deepcopy(dashboard)
    return deepcopy(dashboard)

  def get_daily_rollup(self, _user_id: str, date_key: str) -> dict | None:
    return deepcopy(self.rollups.get(date_key))

  def upsert_daily_rollup(self, _user_id: str, date_key: str, rollup: dict) -> dict:
    self.rollups[date_key] = deepcopy(rollup)
    return deepcopy(rollup)

  def list_daily_rollups(
    self,
    _user_id: str,
    since_date: str | None = None,
    until_date: str | None = None,
  ) -> list[dict]:
    self.list_rollup_calls += 1
    items = list(self.rollups.values())
    if since_date:
      items = [item for item in items if str(item.get("date", "")) >= since_date]
    if until_date:
      items = [item for item in items if str(item.get("date", "")) <= until_date]
    return deepcopy(items)


class _FakeSessionRepository:
  def __init__(self) -> None:
    self.sessions: list[dict] = []

  def list_by_user(self, _user_id: str) -> list[dict]:
    return deepcopy(self.sessions)


def test_dashboard_cache_is_defensive_and_reuses_repository_reads(monkeypatch) -> None:
  analytics = _FakeAnalyticsRepository()
  sessions = _FakeSessionRepository()
  monkeypatch.setattr(service, "get_analytics_repository", lambda: analytics)
  monkeypatch.setattr(service, "get_session_repository", lambda: sessions)
  service.reset_analytics_caches()

  first = service.get_or_build_dashboard("user-1")
  first["ranges"]["7d"]["session_count"] = 999
  second = service.get_or_build_dashboard("user-1")

  assert second["ranges"]["7d"]["session_count"] == 0
  assert analytics.get_dashboard_calls == 1


def test_completed_session_invalidates_dashboard_and_trends(monkeypatch) -> None:
  analytics = _FakeAnalyticsRepository()
  sessions = _FakeSessionRepository()
  monkeypatch.setattr(service, "get_analytics_repository", lambda: analytics)
  monkeypatch.setattr(service, "get_session_repository", lambda: sessions)
  service.reset_analytics_caches()

  service.get_or_build_dashboard("user-1")
  service.build_trends("user-1", "7d")
  # The empty legacy fallback checks the unbounded rollup source after the
  # range query before the cache is populated.
  assert analytics.list_rollup_calls == 3

  service.record_completed_session(
    "user-1",
    {
      "status": "completed",
      "completed_at": int(time() * 1000),
      "overall_score": 80,
      "metrics_summary": {
        "metric_mode": "voice",
        "pitch_accuracy": 80,
        "timing_accuracy": 82,
        "breath_control": 78,
        "pitch_stability": 81,
        "note_transition_smoothness": 79,
        "vibrato_consistency": 77,
      },
    },
  )

  dashboard = service.get_or_build_dashboard("user-1")
  trends = service.build_trends("user-1", "7d")
  assert dashboard["total_completed_sessions"] == 1
  assert any(point["session_count"] == 1 for point in trends["points"])
  assert analytics.get_dashboard_calls == 1
  assert analytics.list_rollup_calls >= 3


def test_unknown_trend_ranges_share_the_canonical_fallback_cache_key(monkeypatch) -> None:
  analytics = _FakeAnalyticsRepository()
  sessions = _FakeSessionRepository()
  monkeypatch.setattr(service, "get_analytics_repository", lambda: analytics)
  monkeypatch.setattr(service, "get_session_repository", lambda: sessions)
  service.reset_analytics_caches()

  service.build_trends("user-1", "not-a-range")
  service.build_trends("user-1", "30d")

  assert analytics.list_rollup_calls == 2
