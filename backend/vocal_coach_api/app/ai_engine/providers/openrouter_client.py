import json
import socket
from time import perf_counter
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class OpenRouterClient:
  def __init__(
    self,
    *,
    api_key: str,
    model: str,
    timeout_s: int,
    temperature: float,
    base_url: str = "https://openrouter.ai/api/v1",
  ) -> None:
    self._api_key = api_key
    self._model = model
    self._timeout_s = timeout_s
    self._temperature = temperature
    self._base_url = base_url.rstrip("/")

  @property
  def model(self) -> str:
    return self._model

  def generate_json(self, *, system_prompt: str, user_prompt: str) -> tuple[dict[str, Any], int]:
    payload = {
      "model": self._model,
      "messages": [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
      ],
      "temperature": self._temperature,
      "response_format": {"type": "json_object"},
    }

    start = perf_counter()
    request = Request(
      url=f"{self._base_url}/chat/completions",
      data=json.dumps(payload).encode("utf-8"),
      headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {self._api_key}",
        "HTTP-Referer": "https://vocal-coach-app.local",
        "X-Title": "Vocal Coach AI",
      },
      method="POST",
    )

    try:
      with urlopen(request, timeout=self._timeout_s) as response:
        raw = response.read().decode("utf-8")
    except (TimeoutError, socket.timeout) as exc:
      raise TimeoutError("OpenRouter request timed out.") from exc
    except HTTPError as exc:
      raise ValueError(f"OpenRouter HTTP error: {exc.code}") from exc
    except URLError as exc:
      reason = str(getattr(exc, "reason", exc)).lower()
      if "timed out" in reason or "timeout" in reason:
        raise TimeoutError("OpenRouter request timed out.") from exc
      raise ValueError("OpenRouter connection failed.") from exc

    latency_ms = int((perf_counter() - start) * 1000)

    try:
      body = json.loads(raw)
    except json.JSONDecodeError as exc:
      raise ValueError("OpenRouter returned invalid JSON payload.") from exc

    choices = body.get("choices")
    if not choices or not isinstance(choices, list):
      raise ValueError("OpenRouter returned no choices.")

    content = (choices[0].get("message") or {}).get("content")
    if not isinstance(content, str) or not content.strip():
      raise ValueError("OpenRouter returned an empty response content.")

    try:
      parsed = json.loads(content)
    except json.JSONDecodeError as exc:
      raise ValueError("OpenRouter response is not valid JSON.") from exc

    if not isinstance(parsed, dict):
      raise ValueError("OpenRouter response JSON must be an object.")
    return parsed, latency_ms
