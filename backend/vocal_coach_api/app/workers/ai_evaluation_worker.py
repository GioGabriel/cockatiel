import logging
from threading import Event, Thread
from time import sleep

from app.core.config import settings
from app.observability.metrics.registry import increment
from app.queue.consumers.ai_evaluation import process_next_ai_evaluation_job

logger = logging.getLogger("vocal-coach-api.ai-worker")


class AIEvaluationWorker:
  def __init__(self, poll_interval_ms: int | None = None) -> None:
    self._poll_interval_ms = max(poll_interval_ms or settings.ai_worker_poll_interval_ms, 50)
    self._stop_event = Event()
    self._thread: Thread | None = None

  def start(self) -> None:
    if self._thread and self._thread.is_alive():
      return
    self._stop_event.clear()
    self._thread = Thread(target=self._run_loop, name="ai-evaluation-worker", daemon=True)
    self._thread.start()
    logger.info("ai_worker_started poll_interval_ms=%s", self._poll_interval_ms)

  def stop(self) -> None:
    self._stop_event.set()
    thread = self._thread
    if thread and thread.is_alive():
      thread.join(timeout=5)
    logger.info("ai_worker_stopped")

  def _run_loop(self) -> None:
    while not self._stop_event.is_set():
      try:
        processed = process_next_ai_evaluation_job()
      except Exception as exc:
        increment("ai_queue_worker_error_total")
        logger.warning("ai_worker_loop_error error=%s", exc)
        processed = False

      if not processed:
        sleep(self._poll_interval_ms / 1000)
