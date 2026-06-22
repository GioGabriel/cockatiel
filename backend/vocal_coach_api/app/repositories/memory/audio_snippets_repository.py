from typing import Any


class InMemoryAudioSnippetRepository:
  def __init__(self) -> None:
    self._snippets: dict[str, dict[str, Any]] = {}

  def create(self, snippet: dict[str, Any]) -> dict[str, Any]:
    snippet_id = str(snippet["snippet_id"])
    self._snippets[snippet_id] = dict(snippet)
    return dict(self._snippets[snippet_id])

  def get(self, snippet_id: str) -> dict[str, Any] | None:
    snippet = self._snippets.get(snippet_id)
    return dict(snippet) if snippet else None

  def list_by_session(self, user_id: str, session_id: str) -> list[dict[str, Any]]:
    snippets = [
      dict(item)
      for item in self._snippets.values()
      if item.get("user_id") == user_id and item.get("session_id") == session_id
    ]
    return sorted(snippets, key=lambda item: int(item.get("created_at", 0)), reverse=True)

  def list_expired(self, expires_before_ms: int, user_id: str | None = None) -> list[dict[str, Any]]:
    snippets = [
      dict(item)
      for item in self._snippets.values()
      if int(item.get("expires_at", 0)) <= expires_before_ms
    ]
    if user_id:
      snippets = [item for item in snippets if item.get("user_id") == user_id]
    return sorted(snippets, key=lambda item: int(item.get("expires_at", 0)))

  def delete(self, snippet_id: str) -> bool:
    return self._snippets.pop(snippet_id, None) is not None
