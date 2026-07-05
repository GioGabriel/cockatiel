"""Unit tests for AI evaluation queue priority ordering."""
import os

os.environ["AUTH_BYPASS"] = "true"
os.environ["FIRESTORE_ENABLED"] = "false"
os.environ["OLLAMA_ENABLED"] = "false"
os.environ["AUDIO_SNIPPET_STORAGE_BACKEND"] = "local"
os.environ["AUDIO_SNIPPET_LOCAL_DIR"] = "/tmp/vocal-coach-audio-test"
os.environ["AUDIO_SNIPPET_RETENTION_DAYS"] = "30"

import pytest

from app.queue.tasks.ai_evaluation_queue import clear, dequeue, enqueue, size


@pytest.fixture(autouse=True)
def _clear_queue() -> None:
  clear()
  yield  # type: ignore[misc]
  clear()


class TestPriorityDequeue:
  def test_premium_dequeued_before_registered(self) -> None:
    enqueue("s1", "u1", priority=2)  # registered
    enqueue("s2", "u2", priority=1)  # premium
    job = dequeue()
    assert job is not None
    assert job["session_id"] == "s2"
    assert job["priority"] == 1

  def test_fifo_within_same_priority(self) -> None:
    enqueue("s1", "u1", priority=2)
    enqueue("s2", "u2", priority=2)
    job = dequeue()
    assert job is not None
    assert job["session_id"] == "s1"

  def test_mixed_priority_sequence(self) -> None:
    enqueue("s1", "u1", priority=2)
    enqueue("s2", "u2", priority=1)
    enqueue("s3", "u3", priority=2)
    enqueue("s4", "u4", priority=1)

    jobs = [dequeue() for _ in range(4)]
    session_ids = [j["session_id"] for j in jobs if j]
    # Premium jobs first (s2, s4 in FIFO), then registered (s1, s3 in FIFO)
    assert session_ids == ["s2", "s4", "s1", "s3"]

  def test_empty_queue_returns_none(self) -> None:
    assert dequeue() is None

  def test_size_reflects_enqueue_dequeue(self) -> None:
    assert size() == 0
    enqueue("s1", "u1", priority=2)
    enqueue("s2", "u2", priority=1)
    assert size() == 2
    dequeue()
    assert size() == 1

  def test_default_priority_is_registered(self) -> None:
    job = enqueue("s1", "u1")
    assert job["priority"] == 2

  def test_premium_priority_value(self) -> None:
    job = enqueue("s1", "u1", priority=1)
    assert job["priority"] == 1
