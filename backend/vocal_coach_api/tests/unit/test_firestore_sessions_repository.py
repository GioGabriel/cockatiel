"""Tests for Firestore session read and update behavior."""

from typing import Any

from app.repositories.firestore.sessions_repository import FirestoreSessionRepository


class _FakeSnapshot:
  def __init__(self, payload: dict[str, Any]) -> None:
    self._payload = payload

  def to_dict(self) -> dict[str, Any]:
    return dict(self._payload)


class _FakeDocument:
  def __init__(self) -> None:
    self.update_calls: list[dict[str, Any]] = []

  def update(self, payload: dict[str, Any]) -> None:
    self.update_calls.append(dict(payload))

  def get(self) -> Any:
    raise AssertionError("session updates must not read Firestore before or after writing")


class _FakeQuery:
  def __init__(self, snapshots: list[_FakeSnapshot]) -> None:
    self.snapshots = snapshots
    self.stream_calls = 0

  def where(self, *_args: Any, **_kwargs: Any) -> "_FakeQuery":
    return self

  def stream(self) -> list[_FakeSnapshot]:
    self.stream_calls += 1
    return list(self.snapshots)


class _FakeCollection:
  def __init__(self, document: _FakeDocument, query: _FakeQuery) -> None:
    self.document_ref = document
    self.query = query

  def document(self, _session_id: str) -> _FakeDocument:
    return self.document_ref

  def where(self, *_args: Any, **_kwargs: Any) -> _FakeQuery:
    return self.query


class _FakeDatabase:
  def __init__(self, document: _FakeDocument, query: _FakeQuery) -> None:
    self.collection_ref = _FakeCollection(document, query)

  def collection(self, _name: str) -> _FakeCollection:
    return self.collection_ref


def test_update_uses_one_write_without_read_after_write() -> None:
  document = _FakeDocument()
  repository = FirestoreSessionRepository(
    _FakeDatabase(document, _FakeQuery([])),
  )

  result = repository.update("session-1", {"status": "processing"})

  assert result == {"status": "processing"}
  assert document.update_calls == [{"status": "processing"}]


def test_list_by_user_reuses_a_short_lived_cache_and_invalidates_after_update() -> None:
  document = _FakeDocument()
  query = _FakeQuery(
    [
      _FakeSnapshot(
        {
          "session_id": "session-1",
          "user_id": "user-1",
          "created_at": 1,
        }
      )
    ]
  )
  repository = FirestoreSessionRepository(
    _FakeDatabase(document, query),
  )

  first = repository.list_by_user("user-1")
  first[0]["status"] = "mutated-locally"
  second = repository.list_by_user("user-1")

  assert second[0].get("status") != "mutated-locally"
  assert query.stream_calls == 1

  repository.update("session-1", {"status": "completed"})
  repository.list_by_user("user-1")

  assert query.stream_calls == 2


def test_force_refresh_bypasses_and_repopulates_the_session_cache() -> None:
  document = _FakeDocument()
  query = _FakeQuery(
    [
      _FakeSnapshot(
        {
          "session_id": "session-1",
          "user_id": "user-1",
          "created_at": 1,
        }
      )
    ]
  )
  repository = FirestoreSessionRepository(
    _FakeDatabase(document, query),
  )

  repository.list_by_user("user-1")
  repository.list_by_user("user-1")
  assert query.stream_calls == 1

  repository.list_by_user("user-1", force_refresh=True)
  repository.list_by_user("user-1")

  assert query.stream_calls == 2
