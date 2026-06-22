def test_auth_me_returns_user_profile(client, auth_headers):
  response = client.get("/v1/auth/me", headers=auth_headers)

  assert response.status_code == 200
  payload = response.json()
  assert payload["uid"] == "test-user"
  assert payload["email"].endswith("@local.dev")
  assert payload["name"] == "Local User"


def test_auth_me_requires_authorization_header(client):
  response = client.get("/v1/auth/me")

  assert response.status_code == 401
  payload = response.json()
  assert payload["error"]["code"] == "AUTH_MISSING"
