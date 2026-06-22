from typing import cast

import app.workers.audio_snippet_cleanup_worker as cleanup_worker
from app.observability.metrics.registry import reset as reset_metrics
from app.observability.metrics.registry import snapshot


def _counters() -> dict[str, int]:
  return cast(dict[str, int], snapshot()["counters"])


def test_cleanup_worker_run_once_updates_metrics(monkeypatch):
  reset_metrics()

  calls: list[dict[str, object]] = []

  def _fake_cleanup(user_id, before_ms=None):
    calls.append({"user_id": user_id, "before_ms": before_ms})
    return {
      "checked_count": 4,
      "removed_count": 3,
      "failed_count": 1,
      "cutoff_ms": 1700000000000,
    }

  monkeypatch.setattr(cleanup_worker, "cleanup_expired_audio_snippets", _fake_cleanup)

  worker = cleanup_worker.AudioSnippetCleanupWorker(interval_seconds=120)
  result = worker.run_once()

  assert result["removed_count"] == 3
  assert calls == [{"user_id": None, "before_ms": None}]
  counters = _counters()
  assert counters.get("audio_snippet_cleanup_runs_total") == 1
  assert counters.get("audio_snippet_cleanup_checked_total") == 4
  assert counters.get("audio_snippet_cleanup_removed_total") == 3
  assert counters.get("audio_snippet_cleanup_failed_total") == 1
