from typing import Any


class FirestoreAudioSnippetRepository:
  collection_name = "audio_snippets"

  def __init__(self, db: Any) -> None:
    self._db = db

  def _doc_ref(self, snippet_id: str):
    return self._db.collection(self.collection_name).document(snippet_id)

  def create(self, snippet: dict[str, Any]) -> dict[str, Any]:
    snippet_id = str(snippet["snippet_id"])
    self._doc_ref(snippet_id).set(snippet)
    return dict(snippet)

  def get(self, snippet_id: str) -> dict[str, Any] | None:
    snap = self._doc_ref(snippet_id).get()
    if not snap.exists:
      return None
    return snap.to_dict()

  def list_by_session(self, user_id: str, session_id: str) -> list[dict[str, Any]]:
    stream = self._db.collection(self.collection_name).where("session_id", "==", session_id).stream()
    snippets = [doc.to_dict() for doc in stream]
    filtered = [item for item in snippets if item.get("user_id") == user_id]
    return sorted(filtered, key=lambda item: int(item.get("created_at", 0)), reverse=True)

  def list_expired(self, expires_before_ms: int, user_id: str | None = None) -> list[dict[str, Any]]:
    stream = self._db.collection(self.collection_name).where("expires_at", "<=", expires_before_ms).stream()
    snippets = [doc.to_dict() for doc in stream]
    if user_id:
      snippets = [item for item in snippets if item.get("user_id") == user_id]
    return sorted(snippets, key=lambda item: int(item.get("expires_at", 0)))

  def delete(self, snippet_id: str) -> bool:
    doc_ref = self._doc_ref(snippet_id)
    snap = doc_ref.get()
    if not snap.exists:
      return False
    doc_ref.delete()
    return True
