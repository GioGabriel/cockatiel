import json
import socket
import time
from time import perf_counter
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


_RETRYABLE_HTTP_STATUS_CODES = {408, 429, 500, 502, 503, 504}


class GoogleAiStudioClient:
  """Small REST client for Google AI Studio's Gemini generateContent API.

  The client deliberately uses the standard library instead of adding another
  SDK to the API container. Keys are tried in order, transient failures are
  retried once, and every request is bounded by one total deadline.
  """

  def __init__(
    self,
    *,
    api_keys: list[str],
    model: str,
    timeout_s: int,
    temperature: float,
    max_output_tokens: int = 256,
    base_url: str = "https://generativelanguage.googleapis.com/v1beta",
    fallback_models: list[str] | None = None,
    max_total_time_s: float = 20.0,
  ) -> None:
    self._api_keys = [key.strip() for key in api_keys if key and key.strip()]
    self._model = model.strip()
    self._timeout_s = max(1, min(timeout_s, 60))
    self._temperature = min(max(temperature, 0.0), 1.0)
    self._max_output_tokens = max(32, min(max_output_tokens, 1024))
    self._base_url = base_url.rstrip("/")
    self._max_total_time_s = max(1.0, min(max_total_time_s, 90.0))
    self._fallback_models = (
      ["gemini-2.5-flash"]
      if fallback_models is None
      else [model_name.strip() for model_name in fallback_models if model_name and model_name.strip()]
    )

  @property
  def model(self) -> str:
    return self._model

  def generate_json(self, *, system_prompt: str, user_prompt: str) -> tuple[dict[str, Any], int]:
    if not self._api_keys:
      raise ValueError("No Google AI API keys configured.")
    if not self._model:
      raise ValueError("No Google AI model configured.")

    models_to_try: list[str] = []
    for model_name in [self._model, *self._fallback_models]:
      if model_name and model_name not in models_to_try:
        models_to_try.append(model_name)

    last_exc: Exception | None = None
    start = perf_counter()
    deadline = start + self._max_total_time_s

    for model_name in models_to_try:
      if perf_counter() >= deadline:
        break
      payload = self._request_payload(system_prompt=system_prompt, user_prompt=user_prompt)
      payload_bytes = json.dumps(payload).encode("utf-8")

      for api_key in self._api_keys:
        for attempt in range(2):
          remaining_s = deadline - perf_counter()
          if remaining_s <= 0:
            break

          request = Request(
            url=(
              f"{self._base_url}/models/{quote(model_name, safe='')}:generateContent"
            ),
            data=payload_bytes,
            headers={
              "Content-Type": "application/json",
              "x-goog-api-key": api_key,
            },
            method="POST",
          )

          try:
            with urlopen(request, timeout=min(self._timeout_s, max(0.1, remaining_s))) as response:
              raw = response.read().decode("utf-8")

            parsed = self._parse_response(raw)
            self._model = model_name
            return parsed, int((perf_counter() - start) * 1000)
          except (TimeoutError, socket.timeout):
            last_exc = TimeoutError("Google AI request timed out.")
            if attempt == 0 and perf_counter() < deadline:
              time.sleep(min(0.2, max(0.0, deadline - perf_counter())))
          except HTTPError as exc:
            last_exc = ValueError(f"Google AI request failed with HTTP status {exc.code}.")
            if exc.code in _RETRYABLE_HTTP_STATUS_CODES and attempt == 0 and perf_counter() < deadline:
              time.sleep(min(0.3, max(0.0, deadline - perf_counter())))
              continue
            break
          except URLError as exc:
            reason = str(getattr(exc, "reason", exc)).lower()
            last_exc = (
              TimeoutError("Google AI request timed out.")
              if "timed out" in reason or "timeout" in reason
              else ValueError("Google AI connection failed.")
            )
            if attempt == 0 and perf_counter() < deadline:
              time.sleep(min(0.2, max(0.0, deadline - perf_counter())))
          except ValueError as exc:
            last_exc = exc
            break
          except Exception:
            last_exc = ValueError("Google AI request failed unexpectedly.")
            break

    raise last_exc or ValueError("Google AI request deadline exceeded.")

  def _request_payload(self, *, system_prompt: str, user_prompt: str) -> dict[str, Any]:
    return {
      "systemInstruction": {"parts": [{"text": system_prompt}]},
      "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
      "generationConfig": {
        "temperature": self._temperature,
        "maxOutputTokens": self._max_output_tokens,
        "responseMimeType": "application/json",
        "responseSchema": {
          "type": "OBJECT",
          "properties": {
            "summary": {
              "type": "STRING",
              "description": "A concise, encouraging coaching summary.",
            },
          },
          "required": ["summary"],
        },
      },
    }

  def _parse_response(self, raw: str) -> dict[str, Any]:
    try:
      body = json.loads(raw)
    except json.JSONDecodeError as exc:
      raise ValueError("Google AI returned invalid JSON payload.") from exc

    if not isinstance(body, dict):
      raise ValueError("Google AI response payload must be an object.")

    candidates = body.get("candidates")
    if not isinstance(candidates, list) or not candidates:
      raise ValueError("Google AI returned no candidates.")

    first_candidate = candidates[0]
    parts = (first_candidate.get("content") or {}).get("parts") if isinstance(first_candidate, dict) else None
    if not isinstance(parts, list):
      raise ValueError("Google AI returned no response parts.")
    content = "".join(
      part.get("text", "")
      for part in parts
      if isinstance(part, dict) and isinstance(part.get("text"), str)
    ).strip()
    if not content:
      raise ValueError("Google AI returned empty response content.")

    try:
      parsed = json.loads(content)
    except json.JSONDecodeError as exc:
      raise ValueError("Google AI response is not valid JSON.") from exc
    if not isinstance(parsed, dict):
      raise ValueError("Google AI response JSON must be an object.")
    return parsed
