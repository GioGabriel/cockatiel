"""Tests for analytics repository write efficiency."""

from typing import Any

from app.repositories.firestore.analytics_repository import FirestoreAnalyticsRepository


class _FakeDocument:
  def __init__(self) -> None:
    self.set_calls: list[tuple[dict[str, Any], bool]] = []

  def set(self, payload: dict[str, Any], *, merge: bool) -> None:
    self.set_calls.append((dict(payload), merge))

  def get(self) -> Any:
    raise AssertionError("analytics upserts must not read Firestore after writing")

  def collection(self, _name: str) -> "_FakeCollection":
    return _FakeCollection(self)


class _FakeCollection:
  def __init__(self, document: _FakeDocument) -> None:
    self.document_ref = document

  def document(self, _document_id: str) -> _FakeDocument:
    return self.document_ref


class _FakeDatabase:
  def __init__(self, document: _FakeDocument) -> None:
    self.document_ref = document

  def collection(self, _name: str) -> _FakeCollection:
    return _FakeCollection(self.document_ref)


def test_dashboard_upsert_does_not_spend_a_read_after_write() -> None:
  document = _FakeDocument()
  repository = FirestoreAnalyticsRepository(_FakeDatabase(document))
  dashboard = {"user_id": "user-1", "streak_days": 2}

  result = repository.upsert_dashboard("user-1", dashboard)

  assert result == dashboard
  assert document.set_calls == [(dashboard, True)]


def test_daily_rollup_upsert_does_not_spend_a_read_after_write() -> None:
  document = _FakeDocument()
  repository = FirestoreAnalyticsRepository(_FakeDatabase(document))
  rollup = {"date": "2026-09-07", "session_count": 1}

  result = repository.upsert_daily_rollup("user-1", "2026-09-07", rollup)

  assert result == rollup
  assert document.set_calls == [(rollup, True)]
