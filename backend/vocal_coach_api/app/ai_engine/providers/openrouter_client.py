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
  ) -> None:
    self._api_keys = api_keys
    self._model = model
    self._timeout_s = timeout_s
    self._temperature = temperature
    self._base_url = base_url.rstrip("/")
    self._fallback_models = fallback_models or [
      "google/gemini-2.5-flash",
      "mistralai/mistral-7b-instruct",
      "meta-llama/llama-3-8b-instruct",
    ]

  @property
  def model(self) -> str:
    return self._model

  def generate_json(self, *, system_prompt: str, user_prompt: str) -> tuple[dict[str, Any], int]:
    # Construct ordered unique list of models to try (primary first, then fallbacks)
    models_to_try = []
    for m in [self._model] + self._fallback_models:
      if m and m not in models_to_try:
        models_to_try.append(m)

    last_exc = None
    start = perf_counter()

    for current_model in models_to_try:
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
        # Up to 2 attempts per key/model with brief backoff for 429s
        for attempt in range(2):
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
            with urlopen(request, timeout=self._timeout_s) as response:
              raw = response.read().decode("utf-8")
            
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

            self._model = current_model
            return parsed, latency_ms

          except (TimeoutError, socket.timeout) as exc:
            last_exc = TimeoutError(f"OpenRouter request timed out on model {current_model}.")
            if attempt == 0:
              time.sleep(0.2)
            continue
          except HTTPError as exc:
            last_exc = ValueError(f"OpenRouter HTTP error: {exc.code} on model {current_model}")
            # Retry on 401 Unauthorized, 402 Payment Required, 403 Forbidden, 429 Too Many Requests, or 5xx server errors
            if exc.code in (401, 402, 403, 429, 500, 502, 503, 504):
              if attempt == 0:
                time.sleep(0.3 * (2 ** attempt))
              continue
            # Non-retryable HTTP error (e.g. 400 Bad Request or 404 Not Found) - break attempt loop
            break
          except URLError as exc:
            reason = str(getattr(exc, "reason", exc)).lower()
            if "timed out" in reason or "timeout" in reason:
              last_exc = TimeoutError(f"OpenRouter request timed out on model {current_model}.")
            else:
              last_exc = ValueError(f"OpenRouter connection failed on model {current_model}.")
            if attempt == 0:
              time.sleep(0.2)
            continue
          except Exception as exc:
            last_exc = exc
            break

    raise last_exc or ValueError("No OpenRouter API keys available or all fallback models failed.")
