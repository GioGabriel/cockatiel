from collections import defaultdict


_counters: dict[str, int] = defaultdict(int)
_histograms: dict[str, list[float]] = defaultdict(list)


def increment(name: str, value: int = 1) -> None:
  _counters[name] += value


def observe(name: str, value: float) -> None:
  _histograms[name].append(value)


def snapshot() -> dict[str, object]:
  return {
    "counters": dict(_counters),
    "histograms": {k: list(v) for k, v in _histograms.items()},
  }


def reset() -> None:
  _counters.clear()
  _histograms.clear()
