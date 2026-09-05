def signup_and_login(client, email="dreamer@example.com", password="supersecret1"):
    resp = client.post(
        "/api/v1/auth/signup",
        json={"email": email, "password": password, "display_name": "Dreamer"},
    )
    assert resp.status_code == 201
    return resp.json()["access_token"]


def test_signup_creates_user_and_free_subscription(client):
    token = signup_and_login(client)
    resp = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == "dreamer@example.com"


def test_duplicate_signup_rejected(client):
    signup_and_login(client)
    resp = client.post(
        "/api/v1/auth/signup",
        json={"email": "dreamer@example.com", "password": "supersecret1"},
    )
    assert resp.status_code == 400


def test_login_wrong_password_rejected(client):
    signup_and_login(client)
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "dreamer@example.com", "password": "wrongpass"},
    )
    assert resp.status_code == 401


def test_submit_dream_returns_interpretation(client):
    token = signup_and_login(client)
    resp = client.post(
        "/api/v1/dreams",
        json={"raw_text": "I was flying over a city made of glass."},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["interpretation"]
    assert body["card_headline"]


def test_free_tier_weekly_limit_enforced(client):
    token = signup_and_login(client)
    headers = {"Authorization": f"Bearer {token}"}

    first = client.post(
        "/api/v1/dreams", json={"raw_text": "Dream one"}, headers=headers
    )
    assert first.status_code == 201

    second = client.post(
        "/api/v1/dreams", json={"raw_text": "Dream two"}, headers=headers
    )
    assert second.status_code == 429


def test_healthcheck(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
