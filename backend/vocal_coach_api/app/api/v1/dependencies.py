from typing import Any, Literal

from fastapi import Depends, Header

from app.core.exceptions import ApiError
from app.core.firebase import firebase_verifier
from app.core.security import extract_bearer_token

AccessTier = Literal["guest", "registered", "premium"]

GUEST_IDENTITY: dict[str, Any] = {"uid": "guest", "tier": "guest"}


def get_current_user(token: str = Depends(extract_bearer_token)) -> dict[str, Any]:
  return firebase_verifier.verify(token)


def get_current_user_or_guest(
  authorization: str | None = Header(default=None),
) -> dict[str, Any]:
  """Return authenticated user with tier metadata, or a synthetic guest identity."""
  if not authorization:
    return GUEST_IDENTITY

  try:
    parts = authorization.split(" ", maxsplit=1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
      return GUEST_IDENTITY
    token = parts[1].strip()
    user = firebase_verifier.verify(token)
    if "tier" not in user:
      user["tier"] = "registered"
    return user
  except (ApiError, Exception):
    return GUEST_IDENTITY
