from typing import Any

from app.core.config import settings
from app.core.exceptions import ApiError


class FirebaseTokenVerifier:
  def verify(self, token: str) -> dict[str, Any]:
    if settings.auth_bypass:
      subject = token.replace("dev_", "") if token else "local-user"
      return {
        "uid": subject,
        "email": f"{subject}@local.dev",
        "name": "Local User",
      }
    raise ApiError(
      code="AUTH_NOT_CONFIGURED",
      message="Firebase verification is not configured for this environment.",
      status_code=501,
    )


firebase_verifier = FirebaseTokenVerifier()
