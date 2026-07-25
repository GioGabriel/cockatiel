import base64
import logging
from typing import Any

logger = logging.getLogger("vocal-coach-api.audio-snippets.firestore")


def _safe_segment(raw: str) -> str:
  cleaned = "".join(char if char.isalnum() or char in {"-", "_"} else "_" for char in raw)
  return cleaned or "unknown"


class FirestoreAudioSnippetStorage:
  backend_name = "firestore"

  def __init__(self, db: Any) -> None:
    self._db = db

  def save(
    self,
    *,
    snippet_id: str,
    user_id: str,
    session_id: str,
    data: bytes,
    extension: str,
  ) -> dict[str, str | int]:
    safe_snippet_id = _safe_segment(snippet_id)
    doc_ref = self._db.collection("audio_snippet_data").document(safe_snippet_id)
    doc_ref.set({
      "snippet_id": safe_snippet_id,
      "user_id": user_id,
      "session_id": session_id,
      "data_base64": base64.b64encode(data).decode("ascii"),
      "extension": extension,
      "size_bytes": len(data),
    })
    logger.info("saved_snippet_to_firestore snippet_id=%s size_bytes=%s", safe_snippet_id, len(data))
    return {
      "storage_backend": self.backend_name,
      "storage_path": f"firestore://audio_snippet_data/{safe_snippet_id}",
      "size_bytes": len(data),
    }

  def delete(self, storage_path: str) -> None:
    try:
      if "audio_snippet_data/" in storage_path:
        doc_id = storage_path.split("audio_snippet_data/")[-1]
        self._db.collection("audio_snippet_data").document(doc_id).delete()
        logger.info("deleted_snippet_from_firestore doc_id=%s", doc_id)
    except Exception as exc:
      logger.warning("failed_to_delete_firestore_snippet path=%s error=%s", storage_path, exc)
      return
