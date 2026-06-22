import json
import socket
from time import perf_counter
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class OllamaClient:
  def __init__(
    self,
    *,
    base_url: str,
    model: str,
    timeout_s: int,
    temperature: float,
  ) -> None:
    self._base_url = base_url.rstrip("/")
    self._model = model
    self._timeout_s = timeout_s
    self._temperature = temperature

  @property
  def model(self) -> str:
    return self._model

  def generate_json(self, *, system_prompt: str, user_prompt: str) -> tuple[dict[str, Any], int]:
    payload = {
      "model": self._model,
      "stream": False,
      "format": "json",
      "messages": [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
      ],
      "options": {"temperature": self._temperature},
    }

    start = perf_counter()
    request = Request(
      url=f"{self._base_url}/api/chat",
      data=json.dumps(payload).encode("utf-8"),
      headers={"Content-Type": "application/json"},
      method="POST",
    )

    try:
      with urlopen(request, timeout=self._timeout_s) as response:
        raw = response.read().decode("utf-8")
    except (TimeoutError, socket.timeout) as exc:
      raise TimeoutError("Ollama request timed out.") from exc
    except HTTPError as exc:
      raise ValueError(f"Ollama HTTP error: {exc.code}") from exc
    except URLError as exc:
      reason = str(getattr(exc, "reason", exc)).lower()
      if "timed out" in reason or "timeout" in reason:
        raise TimeoutError("Ollama request timed out.") from exc
      raise ValueError("Ollama connection failed.") from exc

    latency_ms = int((perf_counter() - start) * 1000)

    try:
      body = json.loads(raw)
    except json.JSONDecodeError as exc:
      raise ValueError("Ollama returned invalid JSON payload.") from exc

    content = (body.get("message") or {}).get("content")
    if not isinstance(content, str) or not content.strip():
      raise ValueError("Ollama returned an empty response content.")

    try:
      parsed = json.loads(content)
    except json.JSONDecodeError as exc:
      raise ValueError("Ollama response is not valid JSON.") from exc

    if not isinstance(parsed, dict):
      raise ValueError("Ollama response JSON must be an object.")
    return parsed, latency_ms
