from concurrent.futures import ThreadPoolExecutor
from threading import Event, Lock

import pytest

from app.repositories.cache.ttl_singleflight import BoundedTtlSingleFlightCache


def test_cache_is_ttl_bounded_and_returns_defensive_copies() -> None:
  now = [100.0]
  cache = BoundedTtlSingleFlightCache[str, dict[str, int]](
    ttl_seconds=10,
    max_entries=2,
    clock=lambda: now[0],
  )

  cache.get_or_load("one", lambda: {"value": 1})
  cached = cache.get_or_load("one", lambda: {"value": 99})
  cached["value"] = 500
  assert cache.get_or_load("one", lambda: {"value": 99}) == {"value": 1}

  cache.get_or_load("two", lambda: {"value": 2})
  cache.get_or_load("three", lambda: {"value": 3})
  assert cache.lookup("one")[0] is False
  assert cache.lookup("two")[0] is True
  assert cache.lookup("three")[0] is True

  now[0] = 111.0
  assert cache.lookup("two")[0] is False


def test_same_key_misses_are_single_flight() -> None:
  cache = BoundedTtlSingleFlightCache[str, dict[str, str]](
    ttl_seconds=30,
    max_entries=8,
  )
  started = Event()
  release = Event()
  calls = 0
  calls_lock = Lock()

  def load() -> dict[str, str]:
    nonlocal calls
    with calls_lock:
      calls += 1
    started.set()
    assert release.wait(2)
    return {"value": "loaded"}

  with ThreadPoolExecutor(max_workers=8) as executor:
    futures = [executor.submit(cache.get_or_load, "same", load) for _ in range(8)]
    assert started.wait(2)
    release.set()
    results = [future.result(timeout=3) for future in futures]

  assert calls == 1
  assert results == [{"value": "loaded"}] * 8


def test_different_keys_do_not_share_the_load_lock() -> None:
  cache = BoundedTtlSingleFlightCache[str, str](ttl_seconds=30, max_entries=8)
  started_one = Event()
  started_two = Event()
  release = Event()

  def load_one() -> str:
    started_one.set()
    assert release.wait(2)
    return "one"

  def load_two() -> str:
    started_two.set()
    assert release.wait(2)
    return "two"

  with ThreadPoolExecutor(max_workers=2) as executor:
    first = executor.submit(cache.get_or_load, "one", load_one)
    second = executor.submit(cache.get_or_load, "two", load_two)
    assert started_one.wait(2)
    assert started_two.wait(2)
    release.set()
    assert first.result(timeout=3) == "one"
    assert second.result(timeout=3) == "two"


def test_invalidation_during_load_does_not_publish_stale_data() -> None:
  cache = BoundedTtlSingleFlightCache[str, dict[str, int]](
    ttl_seconds=30,
    max_entries=8,
  )
  started = Event()
  release = Event()
  calls = 0
  calls_lock = Lock()

  def load() -> dict[str, int]:
    nonlocal calls
    with calls_lock:
      calls += 1
      current_call = calls
    if current_call == 1:
      started.set()
      assert release.wait(2)
    return {"version": current_call}

  with ThreadPoolExecutor(max_workers=1) as executor:
    future = executor.submit(cache.get_or_load, "user-1", load)
    assert started.wait(2)
    cache.invalidate("user-1")
    release.set()
    assert future.result(timeout=3) == {"version": 2}

  assert calls == 2
  assert cache.get_or_load("user-1", lambda: {"version": 99}) == {"version": 2}


def test_loader_errors_are_not_cached() -> None:
  cache = BoundedTtlSingleFlightCache[str, str](ttl_seconds=30, max_entries=8)
  calls = 0

  def load() -> str:
    nonlocal calls
    calls += 1
    if calls == 1:
      raise RuntimeError("temporary Firestore failure")
    return "recovered"

  with pytest.raises(RuntimeError, match="temporary Firestore failure"):
    cache.get_or_load("user-1", load)

  assert cache.get_or_load("user-1", load) == "recovered"
  assert calls == 2
