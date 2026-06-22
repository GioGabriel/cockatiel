import logging
from threading import Event, Thread

from app.modules.audio_snippets.service import cleanup_expired_audio_snippets
from app.observability.metrics.registry import increment

logger = logging.getLogger("vocal-coach-api.audio-snippet-cleanup-worker")


class AudioSnippetCleanupWorker:
  def __init__(self, interval_seconds: int) -> None:
    self._interval_seconds = max(interval_seconds, 10)
    self._stop_event = Event()
    self._thread: Thread | None = None

  def start(self) -> None:
    if self._thread and self._thread.is_alive():
      return
    self._stop_event.clear()
    self._thread = Thread(target=self._run_loop, name="audio-snippet-cleanup-worker", daemon=True)
    self._thread.start()
    logger.info("audio_snippet_cleanup_worker_started interval_seconds=%s", self._interval_seconds)

  def stop(self) -> None:
    self._stop_event.set()
    thread = self._thread
    if thread and thread.is_alive():
      thread.join(timeout=5)
    logger.info("audio_snippet_cleanup_worker_stopped")

  def run_once(self) -> dict[str, int]:
    result = cleanup_expired_audio_snippets(user_id=None)
    increment("audio_snippet_cleanup_runs_total")
    increment("audio_snippet_cleanup_checked_total", result["checked_count"])
    increment("audio_snippet_cleanup_removed_total", result["removed_count"])
    increment("audio_snippet_cleanup_failed_total", result["failed_count"])
    logger.info(
      "audio_snippet_cleanup_run checked_count=%s removed_count=%s failed_count=%s cutoff_ms=%s",
      result["checked_count"],
      result["removed_count"],
      result["failed_count"],
      result["cutoff_ms"],
    )
    return result

  def _run_loop(self) -> None:
    while not self._stop_event.is_set():
      try:
        self.run_once()
      except Exception as exc:
        increment("audio_snippet_cleanup_worker_error_total")
        logger.warning("audio_snippet_cleanup_worker_loop_error error=%s", exc)

      interrupted = self._stop_event.wait(timeout=self._interval_seconds)
      if interrupted:
        break
