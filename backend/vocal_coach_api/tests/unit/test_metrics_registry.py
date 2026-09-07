from concurrent.futures import ThreadPoolExecutor

from app.observability.metrics.registry import increment, reset, snapshot


def test_counter_updates_are_not_lost_under_concurrency() -> None:
  reset()

  def record_batch(_: int) -> None:
    for _ in range(250):
      increment("cache_test_hit_total")

  with ThreadPoolExecutor(max_workers=8) as executor:
    list(executor.map(record_batch, range(8)))

  assert snapshot()["counters"]["cache_test_hit_total"] == 2_000
