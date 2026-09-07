from collections import defaultdict
from threading import RLock


_counters: dict[str, int] = defaultdict(int)
_histograms: dict[str, list[float]] = defaultdict(list)
_lock = RLock()


def increment(name: str, value: int = 1) -> None:
  with _lock:
    _counters[name] += value


def observe(name: str, value: float) -> None:
  with _lock:
    _histograms[name].append(value)


def snapshot() -> dict[str, object]:
  with _lock:
    return {
      "counters": dict(_counters),
      "histograms": {k: list(v) for k, v in _histograms.items()},
    }


def reset() -> None:
  with _lock:
    _counters.clear()
    _histograms.clear()
