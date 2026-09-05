import sys
import types
from types import SimpleNamespace


def test_firebase_verifier_uses_public_app_lifecycle_api(monkeypatch):
  from app.core import firebase

  calls: list[str] = []
  firebase_admin = types.ModuleType("firebase_admin")

  def get_app():
    calls.append("get_app")
    raise ValueError("no default app")

  def initialize_app():
    calls.append("initialize_app")
    return object()

  firebase_admin.get_app = get_app
  firebase_admin.initialize_app = initialize_app
  auth = types.ModuleType("firebase_admin.auth")
  auth.verify_id_token = lambda token, check_revoked: {
    "uid": "firebase-user",
    "email": "singer@example.com",
  }
  firebase_admin.auth = auth

  monkeypatch.setitem(sys.modules, "firebase_admin", firebase_admin)
  monkeypatch.setitem(sys.modules, "firebase_admin.auth", auth)
  monkeypatch.setattr(firebase, "settings", SimpleNamespace(auth_bypass=False))

  result = firebase.FirebaseTokenVerifier().verify("firebase-token")

  assert result["uid"] == "firebase-user"
  assert calls == ["get_app", "initialize_app"]
