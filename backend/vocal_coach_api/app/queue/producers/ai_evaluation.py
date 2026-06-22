from typing import Any

from app.observability.metrics.registry import increment, observe
from app.queue.tasks.ai_evaluation_queue import enqueue, size


def enqueue_ai_evaluation(session_id: str, user_id: str, access_tier: str = "registered") -> dict[str, Any]:
  priority = 1 if access_tier == "premium" else 2
  job = enqueue(session_id=session_id, user_id=user_id, priority=priority)
  increment("ai_queue_enqueued_total")
  observe("ai_queue_depth", float(size()))
  return job
