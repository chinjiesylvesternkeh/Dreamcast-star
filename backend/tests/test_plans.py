import base64
import json
import sys
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app import models
from app.config import get_settings
from app.routers import subscriptions
from app.services import payment_service
from app.services.payment_service import SubscriptionInactive

from tests.conftest import TestingSessionLocal
from tests.test_auth_and_dreams import signup_and_login

RTDN_TOKEN = "rtdn-test-token"


class FakePlay:
    """Stands in for the Google Play Developer API: token -> expiry (None = expired)."""

    expiries: dict = {}

    def verify_mobile_purchase(self, purchase_token, product_id):
        expiry = self.expiries.get(purchase_token)
        if expiry is None or expiry <= datetime.now(timezone.utc):
            raise SubscriptionInactive("expired")
        return {"expiryTimeMillis": str(int(expiry.timestamp() * 1000))}


@pytest.fixture
def play(monkeypatch):
    FakePlay.expiries = {}
    monkeypatch.setattr(subscriptions, "GooglePlayProvider", FakePlay)
    monkeypatch.setattr(payment_service, "GooglePlayProvider", FakePlay)
    monkeypatch.setattr(get_settings(), "GOOGLE_PLAY_RTDN_TOKEN", RTDN_TOKEN)
    return FakePlay.expiries


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _in_days(days):
    return datetime.now(timezone.utc) + timedelta(days=days)


def _verify(client, token, purchase_token="tok-1", product_id="dreamcast_mystic_monthly"):
    return client.post(
        "/api/v1/subscriptions/verify-mobile-purchase",
        json={"purchase_token": purchase_token, "product_id": product_id},
        headers=_auth(token),
    )


def _me(client, token):
    return client.get("/api/v1/subscriptions/me", headers=_auth(token)).json()


def _rtdn(client, purchase_token, product_id, token=RTDN_TOKEN):
    notification = {
        "packageName": "com.dreamcast.app",
        "subscriptionNotification": {
            "notificationType": 2,
            "purchaseToken": purchase_token,
            "subscriptionId": product_id,
        },
    }
    data = base64.b64encode(json.dumps(notification).encode()).decode()
    return client.post(
        f"/api/v1/subscriptions/webhook/google_play?token={token}",
        json={"message": {"data": data}, "subscription": "projects/x/subscriptions/y"},
    )


def test_plans_map_to_play_products(client):
    plans = client.get("/api/v1/subscriptions/plans").json()
    assert [(p["id"], p["product_id"], p["price_usd"]) for p in plans] == [
        ("lucid", "dreamcast_lucid_monthly", "1.79"),
        ("mystic", "dreamcast_mystic_monthly", "3.49"),
        ("oracle", "dreamcast_oracle_monthly", "8.79"),
    ]
    assert all(p["features"] for p in plans)


def test_verified_purchase_activates_its_plan(client, play):
    token = signup_and_login(client)
    play["tok-1"] = _in_days(30)

    resp = _verify(client, token, product_id="dreamcast_oracle_monthly")
    assert resp.status_code == 200
    assert (resp.json()["plan"], resp.json()["provider"]) == ("oracle", "google_play")


def test_unknown_product_rejected(client, play):
    token = signup_and_login(client)
    play["tok-1"] = _in_days(30)
    assert _verify(client, token, product_id="something_else").status_code == 400


def test_expired_purchase_rejected(client, play):
    token = signup_and_login(client)
    assert _verify(client, token).status_code == 400
    assert _me(client, token)["plan"] == "free"


def test_purchase_token_cannot_unlock_a_second_account(client, play):
    play["tok-1"] = _in_days(30)
    first = signup_and_login(client, email="one@example.com")
    second = signup_and_login(client, email="two@example.com")

    assert _verify(client, first).status_code == 200
    assert _verify(client, second).status_code == 409


def test_cancelled_subscription_keeps_access_until_period_end(client, play):
    # Play still reports a future expiry after cancellation; access must remain.
    token = signup_and_login(client)
    play["tok-1"] = _in_days(10)
    _verify(client, token)
    assert _rtdn(client, "tok-1", "dreamcast_mystic_monthly").status_code == 200
    assert _me(client, token)["plan"] == "mystic"


def test_rtdn_expiry_returns_user_to_free(client, play):
    token = signup_and_login(client)
    play["tok-1"] = _in_days(30)
    _verify(client, token)

    play["tok-1"] = None
    assert _rtdn(client, "tok-1", "dreamcast_mystic_monthly").status_code == 200
    me = _me(client, token)
    assert (me["status"], me["plan"]) == ("free", "free")


def test_rtdn_rejects_bad_token(client, play):
    assert _rtdn(client, "tok-1", "dreamcast_mystic_monthly", token="wrong").status_code == 401


def test_lapsed_period_is_rechecked_with_google(client, play):
    token = signup_and_login(client)
    play["tok-1"] = _in_days(30)
    _verify(client, token)

    db = TestingSessionLocal()
    subscription = db.query(models.Subscription).one()
    subscription.current_period_end = datetime.now(timezone.utc) - timedelta(days=1)
    db.commit()
    db.close()

    # Renewed at Google: the period is extended rather than dropped.
    assert _me(client, token)["plan"] == "mystic"

    play["tok-1"] = None
    db = TestingSessionLocal()
    subscription = db.query(models.Subscription).one()
    subscription.current_period_end = datetime.now(timezone.utc) - timedelta(days=1)
    db.commit()
    db.close()
    assert _me(client, token)["plan"] == "free"


def test_paid_plan_daily_limit_enforced(client, play):
    token = signup_and_login(client)
    play["tok-1"] = _in_days(30)
    _verify(client, token, product_id="dreamcast_lucid_monthly")

    assert client.post("/api/v1/dreams", json={"raw_text": "Dream one"}, headers=_auth(token)).status_code == 201
    assert client.post("/api/v1/dreams", json={"raw_text": "Dream two"}, headers=_auth(token)).status_code == 429


def test_deeper_plans_get_longer_readings(client, play):
    token = signup_and_login(client)
    play["tok-1"] = _in_days(30)
    _verify(client, token, product_id="dreamcast_oracle_monthly")

    resp = client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=_auth(token))
    assert resp.json()["interpretation"].count("\n\n") == 2


def test_user_can_report_a_reading(client):
    token = signup_and_login(client)
    dream = client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=_auth(token)).json()

    resp = client.post(
        f"/api/v1/dreams/{dream['id']}/report",
        json={"reason": "offensive", "details": "Not okay"},
        headers=_auth(token),
    )
    assert resp.status_code == 201
    db = TestingSessionLocal()
    assert db.query(models.DreamReport).count() == 1
    db.close()


def test_cannot_report_someone_elses_dream(client):
    owner = signup_and_login(client, email="one@example.com")
    other = signup_and_login(client, email="two@example.com")
    dream = client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=_auth(owner)).json()

    resp = client.post(
        f"/api/v1/dreams/{dream['id']}/report", json={"reason": "other"}, headers=_auth(other)
    )
    assert resp.status_code == 404


def test_account_deletion_removes_all_data(client):
    token = signup_and_login(client)
    dream = client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=_auth(token)).json()
    client.post(f"/api/v1/dreams/{dream['id']}/report", json={"reason": "other"}, headers=_auth(token))

    assert client.delete("/api/v1/users/me", headers=_auth(token)).status_code == 204

    db = TestingSessionLocal()
    assert db.query(models.User).count() == 0
    assert db.query(models.Dream).count() == 0
    assert db.query(models.DreamReport).count() == 0
    assert db.query(models.Subscription).count() == 0
    db.close()
    assert client.get("/api/v1/users/me", headers=_auth(token)).status_code == 401


def test_account_deletion_removes_stored_images(client, monkeypatch):
    from app.routers import users

    deleted = []
    monkeypatch.setattr(users, "delete_dream_images", lambda urls: deleted.extend(urls))
    token = signup_and_login(client)
    client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=_auth(token))

    assert client.delete("/api/v1/users/me", headers=_auth(token)).status_code == 204
    assert len(deleted) == 1


def test_image_keys_are_extracted_from_urls(monkeypatch):
    from app.services import image_service

    calls = []

    class FakeS3:
        def delete_objects(self, Bucket, Delete):
            calls.append([o["Key"] for o in Delete["Objects"]])

    monkeypatch.setattr(get_settings(), "IMAGE_STORAGE_BUCKET", "bucket")
    monkeypatch.setitem(sys.modules, "boto3", SimpleNamespace(client=lambda *args, **kwargs: FakeS3()))
    key = "dream-cards/0b6f3a52-6f1e-4a7e-9a55-3d6f5c2b9e11.png"
    image_service.delete_dream_images([
        f"https://cdn.example.com/{key}",
        f"https://bucket.s3.amazonaws.com/{key}?X-Amz-Signature=x",
        image_service.PLACEHOLDER_IMAGE,
    ])
    assert calls == [[key]]
