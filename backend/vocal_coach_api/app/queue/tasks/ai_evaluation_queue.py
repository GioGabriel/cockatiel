from collections import deque
from threading import Lock
from time import time
from typing import Any
from uuid import uuid4

from app.core.config import settings

_queue: deque[dict[str, Any]] = deque()
_queue_lock = Lock()


def _now_ms() -> int:
  return int(time() * 1000)


def enqueue(session_id: str, user_id: str, priority: int = 2, job_id: str | None = None) -> dict[str, Any]:
  job = {
    "job_id": job_id or str(uuid4()),
    "type": "ai_evaluation",
    "session_id": session_id,
    "user_id": user_id,
    "priority": priority,
    "attempt": 0,
    "max_attempts": max(settings.ai_worker_max_retries, 1),
    "queued_at": _now_ms(),
  }
  with _queue_lock:
    _queue.append(job)
  return dict(job)


def dequeue() -> dict[str, Any] | None:
  with _queue_lock:
    if not _queue:
      return None
    best_idx = 0
    best_priority = _queue[0].get("priority", 2)
    for i in range(1, len(_queue)):
      p = _queue[i].get("priority", 2)
      if p < best_priority:
        best_priority = p
        best_idx = i
    job = _queue[best_idx]
    del _queue[best_idx]
    return dict(job)


def requeue(job: dict[str, Any], error: str | None = None) -> dict[str, Any]:
  updated = dict(job)
  updated["attempt"] = int(updated.get("attempt", 0)) + 1
  updated["queued_at"] = _now_ms()
  if error:
    updated["last_error"] = error
  with _queue_lock:
    _queue.append(updated)
  return dict(updated)


def size() -> int:
  with _queue_lock:
    return len(_queue)


def clear() -> None:
  with _queue_lock:
    _queue.clear()
