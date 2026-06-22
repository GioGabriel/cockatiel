from pathlib import Path


def _safe_segment(raw: str) -> str:
  cleaned = "".join(char if char.isalnum() or char in {"-", "_"} else "_" for char in raw)
  return cleaned or "unknown"


class LocalAudioSnippetStorage:
  backend_name = "local"

  def __init__(self, root_dir: str) -> None:
    self._root_dir = Path(root_dir)
    self._root_dir.mkdir(parents=True, exist_ok=True)

  def save(
    self,
    *,
    snippet_id: str,
    user_id: str,
    session_id: str,
    data: bytes,
    extension: str,
  ) -> dict[str, str | int]:
    user_folder = _safe_segment(user_id)
    session_folder = _safe_segment(session_id)
    safe_snippet_id = _safe_segment(snippet_id)
    safe_extension = "".join(char for char in extension.lower() if char.isalnum()) or "bin"

    folder = self._root_dir / user_folder / session_folder
    folder.mkdir(parents=True, exist_ok=True)

    full_path = folder / f"{safe_snippet_id}.{safe_extension}"
    full_path.write_bytes(data)

    return {
      "storage_backend": self.backend_name,
      "storage_path": str(full_path),
      "size_bytes": len(data),
    }

  def delete(self, storage_path: str) -> None:
    path = Path(storage_path)
    try:
      path.unlink(missing_ok=True)
    except Exception:
      return
