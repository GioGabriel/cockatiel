from collections.abc import Sequence


class OllamaModelRouter:
  def __init__(self, models: Sequence[str]) -> None:
    deduped: list[str] = []
    seen: set[str] = set()
    for model in models:
      normalized = model.strip()
      if not normalized or normalized in seen:
        continue
      deduped.append(normalized)
      seen.add(normalized)
    self._models = tuple(deduped)

  def candidates(self) -> tuple[str, ...]:
    return self._models
