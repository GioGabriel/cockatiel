from collections import OrderedDict
from concurrent.futures import Future
from copy import deepcopy
from dataclasses import dataclass
from time import monotonic
from typing import Callable, Generic, TypeVar

from app.observability.metrics.registry import increment


CacheKey = TypeVar("CacheKey")
CacheValue = TypeVar("CacheValue")


@dataclass(frozen=True)
class _CacheEntry(Generic[CacheValue]):
  expires_at: float
  value: CacheValue


@dataclass(frozen=True)
class _LoadOutcome(Generic[CacheValue]):
  value: CacheValue
  token: tuple[int, int]
  valid: bool


class BoundedTtlSingleFlightCache(Generic[CacheKey, CacheValue]):
  """A bounded, defensive-copying TTL cache for synchronous service code.

  Cache misses for the same key share one loader call. Different keys do not
  hold the cache lock while the loader performs I/O. Invalidation versions
  prevent an in-flight pre-write result from being published after a write.
  """

  def __init__(
    self,
    *,
    ttl_seconds: float,
    max_entries: int,
    name: str | None = None,
    clock: Callable[[], float] = monotonic,
  ) -> None:
    if ttl_seconds <= 0:
      raise ValueError("ttl_seconds must be greater than zero")
    if max_entries <= 0:
      raise ValueError("max_entries must be greater than zero")
    self._ttl_seconds = float(ttl_seconds)
    self._max_entries = int(max_entries)
    self._name = name
    self._clock = clock
    self._entries: OrderedDict[CacheKey, _CacheEntry[CacheValue]] = OrderedDict()
    self._inflight: dict[
      CacheKey,
      tuple[Future[_LoadOutcome[CacheValue]], tuple[int, int]],
    ] = {}
    self._key_generations: OrderedDict[CacheKey, int] = OrderedDict()
    self._global_generation = 0
    # The cache is accessed by FastAPI's synchronous worker threads.
    from threading import RLock

    self._lock = RLock()

  def lookup(self, key: CacheKey) -> tuple[bool, CacheValue | None]:
    """Return `(found, value)` while distinguishing a cached `None` value."""
    with self._lock:
      return self._lookup_locked(key, self._clock())

  def get_or_load(
    self,
    key: CacheKey,
    loader: Callable[[], CacheValue],
  ) -> CacheValue:
    while True:
      found, value = self.lookup(key)
      if found:
        self._metric("hit")
        return value  # type: ignore[return-value]

      self._metric("miss")

      with self._lock:
        found, value = self._lookup_locked(key, self._clock())
        if found:
          self._metric("hit")
          return value  # type: ignore[return-value]

        flight = self._inflight.get(key)
        if flight is None:
          future: Future[_LoadOutcome[CacheValue]] = Future()
          token = self._token_locked(key)
          self._inflight[key] = (future, token)
          is_owner = True
        else:
          future, token = flight
          is_owner = False

      if not is_owner:
        self._metric("singleflight_wait")
        outcome = future.result()
        with self._lock:
          current_token = self._token_locked(key)
        if outcome.valid and outcome.token == current_token:
          return deepcopy(outcome.value)
        # An invalidation happened while the shared load was running. Retry
        # instead of returning data that was known to be superseded.
        continue

      try:
        self._metric("load")
        loaded = loader()
      except BaseException as error:
        self._metric("load_error")
        with self._lock:
          if not future.done():
            future.set_exception(error)
          if self._inflight.get(key, (None, None))[0] is future:
            self._inflight.pop(key, None)
        raise

      with self._lock:
        current_token = self._token_locked(key)
        valid = token == current_token
        if valid:
          self._store_locked(key, loaded)
        outcome = _LoadOutcome(value=loaded, token=token, valid=valid)
        if not future.done():
          future.set_result(outcome)
        if self._inflight.get(key, (None, None))[0] is future:
          self._inflight.pop(key, None)

      if valid:
        return deepcopy(loaded)
      # A write invalidated this load before it completed. Load again so the
      # caller and the cache observe the post-write state.

  def invalidate(self, key: CacheKey) -> None:
    with self._lock:
      self._entries.pop(key, None)
      self._key_generations[key] = self._key_generations.get(key, 0) + 1
      self._key_generations.move_to_end(key)
      self._trim_generations_locked()
    self._metric("invalidate")

  def invalidate_all(self) -> None:
    with self._lock:
      self._entries.clear()
      self._global_generation += 1
    self._metric("invalidate_all")

  def clear(self) -> None:
    """Alias used by tests and lifecycle reset hooks."""
    self.invalidate_all()

  def _lookup_locked(
    self,
    key: CacheKey,
    now: float,
  ) -> tuple[bool, CacheValue | None]:
    entry = self._entries.get(key)
    if entry is None:
      return False, None
    if entry.expires_at <= now:
      self._entries.pop(key, None)
      return False, None
    self._entries.move_to_end(key)
    return True, deepcopy(entry.value)

  def _store_locked(self, key: CacheKey, value: CacheValue) -> None:
    self._entries[key] = _CacheEntry(
      expires_at=self._clock() + self._ttl_seconds,
      value=deepcopy(value),
    )
    self._entries.move_to_end(key)
    while len(self._entries) > self._max_entries:
      self._entries.popitem(last=False)
      self._metric("eviction")

  def _token_locked(self, key: CacheKey) -> tuple[int, int]:
    return self._global_generation, self._key_generations.get(key, 0)

  def _trim_generations_locked(self) -> None:
    maximum = self._max_entries * 2
    if len(self._key_generations) <= maximum:
      return
    active_keys = set(self._entries) | set(self._inflight)
    for key in list(self._key_generations):
      if len(self._key_generations) <= self._max_entries:
        break
      if key not in active_keys:
        self._key_generations.pop(key, None)

  def _metric(self, event: str) -> None:
    if self._name:
      increment(f"cache_{self._name}_{event}_total")
