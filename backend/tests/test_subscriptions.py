from app import models
from app.routers import subscriptions

from tests.test_auth_and_dreams import signup_and_login


class FakeProvider:
    def __init__(self, event):
        self.event = event

    def verify_webhook(self, payload, signature):
        return self.event


def test_stripe_webhook_activates_subscription(client, monkeypatch):
    token = signup_and_login(client)
    monkeypatch.setattr(
        subscriptions,
        "get_payment_provider",
        lambda: FakeProvider(
            {
                "type": "checkout.session.completed",
                "data": {
                    "object": {
                        "customer_email": "dreamer@example.com",
                        "subscription": "sub_123",
                    }
                },
            }
        ),
    )

    response = client.post("/api/v1/subscriptions/webhook/stripe", content=b"{}")

    assert response.status_code == 200
    subscription = client.get(
        "/api/v1/subscriptions/me", headers={"Authorization": f"Bearer {token}"}
    ).json()
    assert subscription["status"] == models.SubscriptionStatus.ACTIVE.value
    assert subscription["provider"] == models.SubscriptionProvider.STRIPE.value


def test_stripe_webhook_marks_payment_failure_past_due(client, monkeypatch):
    token = signup_and_login(client)
    monkeypatch.setattr(
        subscriptions,
        "get_payment_provider",
        lambda: FakeProvider(
            {
                "type": "invoice.payment_failed",
                "data": {"object": {"customer_email": "dreamer@example.com"}},
            }
        ),
    )

    response = client.post("/api/v1/subscriptions/webhook/stripe", content=b"{}")

    assert response.status_code == 200
    subscription = client.get(
        "/api/v1/subscriptions/me", headers={"Authorization": f"Bearer {token}"}
    ).json()
    assert subscription["status"] == models.SubscriptionStatus.PAST_DUE.value
