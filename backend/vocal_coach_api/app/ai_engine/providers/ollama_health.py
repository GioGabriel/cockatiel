import json
import socket
from time import perf_counter
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def list_ollama_models(*, base_url: str, timeout_s: int) -> tuple[list[str], int]:
  request = Request(url=f"{base_url.rstrip('/')}/api/tags", method="GET")
  start = perf_counter()
  try:
    with urlopen(request, timeout=timeout_s) as response:
      raw = response.read().decode("utf-8")
  except (TimeoutError, socket.timeout) as exc:
    raise TimeoutError("Ollama tags request timed out.") from exc
  except HTTPError as exc:
    raise ValueError(f"Ollama HTTP error: {exc.code}") from exc
  except URLError as exc:
    reason = str(getattr(exc, "reason", exc)).lower()
    if "timed out" in reason or "timeout" in reason:
      raise TimeoutError("Ollama tags request timed out.") from exc
    raise ValueError("Ollama connection failed.") from exc

  latency_ms = int((perf_counter() - start) * 1000)

  try:
    payload = json.loads(raw)
  except json.JSONDecodeError as exc:
    raise ValueError("Ollama tags response was not valid JSON.") from exc

  models = payload.get("models", [])
  if not isinstance(models, list):
    raise ValueError("Ollama tags response missing models list.")

  names: list[str] = []
  for item in models:
    if isinstance(item, dict):
      name = item.get("name")
      if isinstance(name, str) and name.strip():
        names.append(name.strip())

  return names, latency_ms
