from datetime import datetime, timedelta, timezone

import pytest

from app import models
from app.config import get_settings
from app.services import flutterwave

from tests.conftest import TestingSessionLocal
from tests.test_auth_and_dreams import signup_and_login

WEBHOOK_SECRET = "test-hash"


@pytest.fixture
def flw(monkeypatch):
    """Configures Flutterwave and serves fake verified transactions by id."""
    settings = get_settings()
    monkeypatch.setattr(settings, "FLW_SECRET_KEY", "FLWSECK_TEST")
    monkeypatch.setattr(settings, "FLW_WEBHOOK_SECRET", WEBHOOK_SECRET)
    transactions = {}
    monkeypatch.setattr(flutterwave, "verify_transaction", lambda tx_id: transactions[tx_id])
    return transactions


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _user_id(client, token):
    return client.get("/api/v1/users/me", headers=_auth(token)).json()["id"]


def _transaction(user_id, plan, amount, tx_id="1001", currency="XAF", status="successful"):
    return {
        "id": int(tx_id),
        "tx_ref": flutterwave.build_tx_ref(user_id, plan),
        "amount": amount,
        "currency": currency,
        "status": status,
    }


def _webhook(client, tx_id, secret=WEBHOOK_SECRET):
    return client.post(
        "/api/v1/subscriptions/webhook/flutterwave",
        json={"event": "charge.completed", "data": {"id": int(tx_id)}},
        headers={"verif-hash": secret},
    )


def _me(client, token):
    return client.get("/api/v1/subscriptions/me", headers=_auth(token)).json()


def test_plans_are_priced_in_xaf(client):
    plans = client.get("/api/v1/subscriptions/plans").json()
    assert [(p["id"], p["price_xaf"], p["currency"]) for p in plans] == [
        ("lucid", 1000, "XAF"),
        ("mystic", 2000, "XAF"),
        ("oracle", 5000, "XAF"),
    ]
    assert all(p["features"] for p in plans)


def test_new_user_is_on_free_plan(client):
    token = signup_and_login(client)
    assert _me(client, token)["plan"] == "free"


def test_checkout_unavailable_until_flutterwave_configured(client):
    token = signup_and_login(client)
    resp = client.post(
        "/api/v1/subscriptions/flutterwave/checkout", json={"plan": "mystic"}, headers=_auth(token)
    )
    assert resp.status_code == 503


def test_checkout_rejects_unknown_plan(client, flw):
    token = signup_and_login(client)
    resp = client.post(
        "/api/v1/subscriptions/flutterwave/checkout", json={"plan": "free"}, headers=_auth(token)
    )
    assert resp.status_code == 404


def test_webhook_activates_paid_plan_once(client, flw):
    token = signup_and_login(client)
    flw["1001"] = _transaction(_user_id(client, token), "mystic", 2000)

    assert _webhook(client, "1001").status_code == 200
    first = _me(client, token)
    assert (first["status"], first["plan"], first["provider"]) == ("active", "mystic", "flutterwave")

    # The redirect delivering the same payment must not extend the period again.
    assert _webhook(client, "1001").status_code == 200
    assert _me(client, token)["current_period_end"] == first["current_period_end"]


def test_return_page_confirms_payment(client, flw):
    token = signup_and_login(client)
    flw["1002"] = _transaction(_user_id(client, token), "oracle", 5000, tx_id="1002")

    resp = client.get("/api/v1/subscriptions/flutterwave/return?transaction_id=1002")
    assert resp.status_code == 200
    assert "Welcome to Oracle" in resp.text
    assert _me(client, token)["plan"] == "oracle"


def test_underpayment_is_ignored(client, flw):
    token = signup_and_login(client)
    flw["1003"] = _transaction(_user_id(client, token), "oracle", 1000, tx_id="1003")

    _webhook(client, "1003")
    assert _me(client, token)["plan"] == "free"


def test_webhook_rejects_bad_signature(client, flw):
    assert _webhook(client, "1001", secret="wrong").status_code == 401


def test_paid_plan_daily_limit_enforced(client, flw):
    token = signup_and_login(client)
    flw["1004"] = _transaction(_user_id(client, token), "lucid", 1000, tx_id="1004")
    _webhook(client, "1004")

    first = client.post("/api/v1/dreams", json={"raw_text": "Dream one"}, headers=_auth(token))
    assert first.status_code == 201
    second = client.post("/api/v1/dreams", json={"raw_text": "Dream two"}, headers=_auth(token))
    assert second.status_code == 429


def test_deeper_plans_get_longer_readings(client, flw):
    token = signup_and_login(client)
    flw["1005"] = _transaction(_user_id(client, token), "oracle", 5000, tx_id="1005")
    _webhook(client, "1005")

    resp = client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=_auth(token))
    assert resp.json()["interpretation"].count("\n\n") == 2


def test_lapsed_flutterwave_plan_returns_to_free(client, flw):
    token = signup_and_login(client)
    user_id = _user_id(client, token)
    flw["1006"] = _transaction(user_id, "mystic", 2000, tx_id="1006")
    _webhook(client, "1006")

    db = TestingSessionLocal()
    subscription = db.query(models.Subscription).filter_by(user_id=user_id).one()
    subscription.current_period_end = datetime.now(timezone.utc) - timedelta(days=3)
    db.commit()
    db.close()

    me = _me(client, token)
    assert (me["status"], me["plan"]) == ("free", "free")
