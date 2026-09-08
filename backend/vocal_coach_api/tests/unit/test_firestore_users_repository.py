"""Tests for the production Firestore user repository."""

from typing import Any

from app.repositories.firestore.users_repository import FirestoreUserRepository


class _FakeDocument:
  def __init__(self) -> None:
    self.set_calls: list[tuple[dict[str, Any], bool]] = []
    self.update_calls: list[dict[str, Any]] = []

  def set(self, payload: dict[str, Any], *, merge: bool) -> None:
    self.set_calls.append((payload, merge))

  def get(self) -> Any:
    raise AssertionError("auth/me must not read Firestore after the upsert write")

  def update(self, payload: dict[str, Any]) -> None:
    self.update_calls.append(payload)


class _FakeCollection:
  def __init__(self, document: _FakeDocument) -> None:
    self._document = document

  def document(self, _: str) -> _FakeDocument:
    return self._document


class _FakeDatabase:
  def __init__(self, document: _FakeDocument) -> None:
    self._collection = _FakeCollection(document)

  def collection(self, _: str) -> _FakeCollection:
    return self._collection


def test_upsert_does_not_spend_a_firestore_read_for_auth_bootstrap() -> None:
  document = _FakeDocument()
  repository = FirestoreUserRepository(_FakeDatabase(document))

  result = repository.upsert(
    {
      "uid": "user-1",
      "email": "singer@example.com",
      "name": "Singer",
      "access_tier": "premium",
    }
  )

  assert result == {
    "uid": "user-1",
    "email": "singer@example.com",
    "name": "Singer",
  }
  assert len(document.set_calls) == 1
  payload, merge = document.set_calls[0]
  assert merge is True
  assert payload["uid"] == "user-1"
  assert payload["email"] == "singer@example.com"
  assert payload["name"] == "Singer"
  assert "access_tier" not in payload
  assert isinstance(payload["updated_at"], str)


def test_update_does_not_read_before_or_after_the_write() -> None:
  document = _FakeDocument()
  repository = FirestoreUserRepository(_FakeDatabase(document))

  result = repository.update("user-1", {"access_tier": "premium"})

  assert result is not None
  assert result["access_tier"] == "premium"
  assert isinstance(result["updated_at"], str)
  assert len(document.update_calls) == 1
