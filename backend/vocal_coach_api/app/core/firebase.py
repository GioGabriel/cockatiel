import base64
import json
from typing import Any

from app.core.config import settings
from app.core.exceptions import ApiError


class FirebaseTokenVerifier:
  def verify(self, token: str) -> dict[str, Any]:
    import logging
    logging.getLogger("vocal-coach-api").info("FirebaseTokenVerifier received token: %s", token)
    if token and len(token.split(".")) == 3:
      try:
        payload_b64 = token.split(".")[1]
        payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        uid = payload.get("user_id") or payload.get("sub") or "unknown-uid"
        email = payload.get("email") or f"{uid}@local.dev"
        name = payload.get("name") or "Local User"
        return {"uid": uid, "email": email, "name": name}
      except Exception as e:
        import logging
        logging.getLogger("vocal-coach-api").error("JWT Parsing Failed: %s, token: %s", e, token)
        pass

    if settings.auth_bypass:
      subject = token.replace("dev_", "") if token else "local-user"
      return {
        "uid": subject[:30],
        "email": f"{subject[:10]}@local.dev",
        "name": "Local User",
      }
    raise ApiError(
      code="AUTH_NOT_CONFIGURED",
      message="Firebase verification is not configured for this environment.",
      status_code=501,
    )


firebase_verifier = FirebaseTokenVerifier()
