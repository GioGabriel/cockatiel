from typing import Any
import logging

from app.core.config import settings
from app.core.exceptions import ApiError

logger = logging.getLogger("vocal-coach-api.auth")


class FirebaseTokenVerifier:
  def verify(self, token: str) -> dict[str, Any]:
    if settings.auth_bypass:
      subject = token.replace("dev_", "") if token else "local-user"
      return {
        "uid": subject[:30],
        "email": f"{subject[:10]}@local.dev",
        "name": "Local User",
      }

    try:
      import firebase_admin
      from firebase_admin import auth

      try:
        firebase_admin.get_app()
      except ValueError:
        firebase_admin.initialize_app()
      decoded = auth.verify_id_token(token, check_revoked=True)
      uid = str(decoded["uid"])
      return {
        "uid": uid,
        "email": str(decoded.get("email") or f"{uid}@firebase.local"),
        "name": str(decoded.get("name") or "Vocal Coach user"),
      }
    except ImportError:
      logger.error(
        "Firebase Admin SDK is unavailable while authentication bypass is disabled."
      )
      raise ApiError(
        code="AUTH_NOT_CONFIGURED",
        message="Firebase verification is not configured for this environment.",
        status_code=501,
      )
    except Exception as exc:
      logger.warning(
        "Firebase token verification failed: %s", type(exc).__name__
      )
      raise ApiError(
        code="AUTH_INVALID",
        message="Authentication token is invalid or expired.",
        status_code=401,
      ) from exc


firebase_verifier = FirebaseTokenVerifier()
