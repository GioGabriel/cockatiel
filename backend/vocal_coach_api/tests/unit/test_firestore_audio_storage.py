import json

import pytest

from app.core.exceptions import ApiError
from app.storage.audio_snippets.adapters.firestore.storage import FirestoreAudioSnippetStorage


class FakeDatabase:
  def __init__(self, *, fail_delete=False):
    self.payload = None
    self.fail_delete = fail_delete

  def collection(self, _name):
    return self

  def document(self, _name):
    return self

  def set(self, payload):
    self.payload = payload

  def delete(self):
    if self.fail_delete:
      raise RuntimeError("storage deletion unavailable")


def save(storage, data):
  return storage.save(snippet_id="snippet", user_id="user", session_id="session", data=data, extension="wav")


def test_firestore_audio_rejects_data_that_would_exceed_document_limit_before_writing():
  database = FakeDatabase()
  with pytest.raises(ApiError) as error:
    save(FirestoreAudioSnippetStorage(database), b"x" * 750_001)
  assert error.value.status_code == 413
  assert database.payload is None


def test_firestore_audio_boundary_fits_with_metadata_below_one_mebibyte():
  database = FakeDatabase()
  result = save(FirestoreAudioSnippetStorage(database), b"x" * 750_000)
  assert result["size_bytes"] == 750_000
  assert len(json.dumps(database.payload).encode()) < 1_048_576


def test_firestore_audio_does_not_hide_deletion_failure_from_retention_worker():
  with pytest.raises(RuntimeError, match="storage deletion unavailable"):
    FirestoreAudioSnippetStorage(FakeDatabase(fail_delete=True)).delete("firestore://audio_snippet_data/snippet")
