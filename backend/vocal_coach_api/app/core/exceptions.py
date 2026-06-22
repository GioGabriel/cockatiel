from dataclasses import dataclass
from typing import Any


@dataclass
class ApiError(Exception):
  code: str
  message: str
  status_code: int = 400
  details: dict[str, Any] | None = None


def error_envelope(code: str, message: str, trace_id: str, details: dict[str, Any] | None = None) -> dict[str, Any]:
  return {
    "error": {
      "code": code,
      "message": message,
      "details": details or {},
      "trace_id": trace_id,
    }
  }
