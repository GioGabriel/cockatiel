from typing import Any, Literal

from fastapi import Depends, Header

from app.core.firebase import firebase_verifier
from app.core.security import extract_bearer_token

AccessTier = Literal["guest", "registered", "premium"]

GUEST_IDENTITY: dict[str, Any] = {"uid": "guest", "tier": "guest"}


def get_current_user(token: str = Depends(extract_bearer_token)) -> dict[str, Any]:
  return firebase_verifier.verify(token)


def get_current_user_or_guest(
  authorization: str | None = Header(default=None),
) -> dict[str, Any]:
  """Return a guest only when no credential was supplied.

  A malformed or rejected credential must never silently downgrade to guest. That
  behavior makes client auth bugs look like successful anonymous requests and can
  hide authorization failures in production.
  """
  if not authorization:
    return dict(GUEST_IDENTITY)

  token = extract_bearer_token(authorization)
  user = firebase_verifier.verify(token)
  if "tier" not in user:
    user["tier"] = "registered"
  return user
