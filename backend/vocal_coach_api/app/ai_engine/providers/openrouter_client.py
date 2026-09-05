import json
import socket
import time
from time import perf_counter
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class OpenRouterClient:
  def __init__(
    self,
    *,
    api_keys: list[str],
    model: str,
    timeout_s: int,
    temperature: float,
    base_url: str = "https://openrouter.ai/api/v1",
    fallback_models: list[str] | None = None,
    max_total_time_s: float = 20.0,
  ) -> None:
    self._api_keys = [key.strip() for key in api_keys if key and key.strip()]
    self._model = model
    self._timeout_s = max(1, min(timeout_s, 60))
    self._temperature = temperature
    self._base_url = base_url.rstrip("/")
    self._max_total_time_s = max(1.0, min(max_total_time_s, 90.0))
    self._fallback_models = [
      "google/gemini-2.5-flash",
      "mistralai/mistral-7b-instruct",
      "meta-llama/llama-3-8b-instruct",
    ] if fallback_models is None else list(fallback_models)

  @property
  def model(self) -> str:
    return self._model

  def generate_json(self, *, system_prompt: str, user_prompt: str) -> tuple[dict[str, Any], int]:
    if not self._api_keys:
      raise ValueError("No OpenRouter API keys configured.")

    # Construct ordered unique list of models to try (primary first, then fallbacks)
    models_to_try = []
    for m in [self._model] + self._fallback_models:
      if m and m not in models_to_try:
        models_to_try.append(m)

    last_exc: Exception | None = None
    start = perf_counter()
    deadline = start + self._max_total_time_s

    for current_model in models_to_try:
      if perf_counter() >= deadline:
        break
      payload = {
        "model": current_model,
        "messages": [
          {"role": "system", "content": system_prompt},
          {"role": "user", "content": user_prompt},
        ],
        "temperature": self._temperature,
        "response_format": {"type": "json_object"},
      }
      payload_bytes = json.dumps(payload).encode("utf-8")

      for api_key in self._api_keys:
        # Up to two attempts per key/model, bounded by one total deadline.
        for attempt in range(2):
          remaining_s = deadline - perf_counter()
          if remaining_s <= 0:
            break
          request = Request(
            url=f"{self._base_url}/chat/completions",
            data=payload_bytes,
            headers={
              "Content-Type": "application/json",
              "Authorization": f"Bearer {api_key}",
              "HTTP-Referer": "https://vocal-coach-app.local",
              "X-Title": "Vocal Coach AI",
            },
            method="POST",
          )

          try:
            with urlopen(request, timeout=min(self._timeout_s, max(0.1, remaining_s))) as response:
              raw = response.read().decode("utf-8")

            latency_ms = int((perf_counter() - start) * 1000)

            try:
              body = json.loads(raw)
            except json.JSONDecodeError as exc:
              raise ValueError("OpenRouter returned invalid JSON payload.") from exc

            if not isinstance(body, dict):
              raise ValueError("OpenRouter response payload must be an object.")

            choices = body.get("choices")
            if not choices or not isinstance(choices, list):
              raise ValueError("OpenRouter returned no choices.")

            first_choice = choices[0]
            content = (first_choice.get("message") or {}).get("content") if isinstance(first_choice, dict) else None
            if not isinstance(content, str) or not content.strip():
              raise ValueError("OpenRouter returned an empty response content.")

            try:
              parsed = json.loads(content)
            except json.JSONDecodeError as exc:
              raise ValueError("OpenRouter response is not valid JSON.") from exc

            if not isinstance(parsed, dict):
              raise ValueError("OpenRouter response JSON must be an object.")

            self._model = current_model
            return parsed, latency_ms

          except (TimeoutError, socket.timeout):
            last_exc = TimeoutError("OpenRouter request timed out.")
            if attempt == 0 and perf_counter() < deadline:
              time.sleep(min(0.2, max(0.0, deadline - perf_counter())))
            continue
          except HTTPError as exc:
            last_exc = ValueError(f"OpenRouter request failed with HTTP status {exc.code}.")
            # Invalid credentials and malformed requests are not transient. Move
            # to the next key/model without spending another attempt on them.
            if exc.code in (429, 500, 502, 503, 504):
              if attempt == 0 and perf_counter() < deadline:
                time.sleep(min(0.3, max(0.0, deadline - perf_counter())))
              continue
            break
          except URLError as exc:
            reason = str(getattr(exc, "reason", exc)).lower()
            if "timed out" in reason or "timeout" in reason:
              last_exc = TimeoutError("OpenRouter request timed out.")
            else:
              last_exc = ValueError("OpenRouter connection failed.")
            if attempt == 0 and perf_counter() < deadline:
              time.sleep(min(0.2, max(0.0, deadline - perf_counter())))
            continue
          except ValueError as exc:
            # Payload/schema shape errors are safe to report internally but must
            # not trigger an unbounded retry storm.
            last_exc = exc
            break
          except Exception:
            last_exc = ValueError("OpenRouter request failed unexpectedly.")
            break

    raise last_exc or ValueError("OpenRouter request deadline exceeded.")
