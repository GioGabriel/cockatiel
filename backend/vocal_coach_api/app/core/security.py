from fastapi import Header

from app.core.exceptions import ApiError


def extract_bearer_token(authorization: str | None = Header(default=None)) -> str:
  if not authorization:
    raise ApiError(code="AUTH_MISSING", message="Missing Authorization header.", status_code=401)

  parts = authorization.split(" ", maxsplit=1)
  if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
    raise ApiError(code="AUTH_INVALID", message="Invalid bearer token format.", status_code=401)
  return parts[1].strip()
