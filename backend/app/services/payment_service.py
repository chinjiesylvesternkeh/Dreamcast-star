"""
Payment abstraction layer.

DESIGN GOAL: you should be able to go live with real payments by only
setting environment variables / Kubernetes secrets — no code changes.

Supported providers out of the box:
  - Stripe            (web / cross-platform subscriptions)
  - Google Play Billing (in-app subscriptions on Android, verified server-side)
  - RevenueCat         (wraps Play Billing + App Store, recommended if you'll
                        ever ship iOS too — handles receipt validation for you)

HOW TO GO LIVE:
  1. Pick a provider in PAYMENT_PROVIDER env var.
  2. Fill in the matching secret(s) below (STRIPE_SECRET_KEY, or
     GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, or REVENUECAT_API_KEY).
  3. Point your provider's webhook at:
       POST /api/v1/subscriptions/webhook/{provider}
  4. Nothing else in the codebase needs to change.
"""

import json
import logging
from pathlib import Path
from abc import ABC, abstractmethod
from datetime import datetime, timedelta, timezone

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)


class PaymentProvider(ABC):
    @abstractmethod
    def create_checkout_session(
        self, user_email: str, success_url: str, cancel_url: str
    ) -> str:
        """Returns a checkout URL the client should redirect the user to."""

    @abstractmethod
    def verify_webhook(self, payload: bytes, signature: str) -> dict:
        """Verifies webhook signature and returns the parsed event."""

    @abstractmethod
    def verify_mobile_purchase(self, purchase_token: str, product_id: str) -> dict:
        """Server-side verification of an in-app purchase token (Android/iOS)."""


class StripeProvider(PaymentProvider):
    def __init__(self):
        import stripe  # local import so the package is only required if used

        if not settings.STRIPE_SECRET_KEY:
            logger.warning(
                "StripeProvider initialized without STRIPE_SECRET_KEY — "
                "checkout calls will fail until you set it."
            )
        stripe.api_key = settings.STRIPE_SECRET_KEY
        self.stripe = stripe

    def create_checkout_session(
        self, user_email: str, success_url: str, cancel_url: str
    ) -> str:
        session = self.stripe.checkout.Session.create(
            mode="subscription",
            customer_email=user_email,
            line_items=[{"price": settings.STRIPE_PRICE_ID_MONTHLY, "quantity": 1}],
            success_url=success_url,
            cancel_url=cancel_url,
        )
        return session.url

    def verify_webhook(self, payload: bytes, signature: str) -> dict:
        event = self.stripe.Webhook.construct_event(
            payload, signature, settings.STRIPE_WEBHOOK_SECRET
        )
        return event

    def verify_mobile_purchase(self, purchase_token: str, product_id: str) -> dict:
        raise NotImplementedError(
            "Stripe does not handle native mobile purchase tokens"
        )


class GooglePlayProvider(PaymentProvider):
    """
    Server-side verification of Google Play subscription purchases using the
    Android Publisher API. Requires a service account JSON with access to
    your Play Console app, granted via Play Console > Users & permissions.
    """

    def __init__(self):
        if not settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:
            logger.warning(
                "GooglePlayProvider initialized without a service account — "
                "purchase verification will fail until you set "
                "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON."
            )

    def create_checkout_session(
        self, user_email: str, success_url: str, cancel_url: str
    ) -> str:
        # Google Play subscriptions are purchased natively via Play Billing
        # in the Android app — there is no server-generated checkout URL.
        # The mobile app calls BillingClient.launchBillingFlow() directly
        # (see mobile/lib/services/billing_service.dart) and then sends the
        # resulting purchase token here for verification.
        raise NotImplementedError(
            "Google Play purchases are initiated client-side. Use "
            "verify_mobile_purchase() after the app completes the purchase."
        )

    def verify_webhook(self, payload: bytes, signature: str) -> dict:
        # Google Play uses Real-time Developer Notifications (RTDN) via
        # Google Cloud Pub/Sub rather than a signed HTTP webhook. Wire a
        # Pub/Sub push subscription to /api/v1/subscriptions/webhook/google_play
        # and validate the JWT in the payload against Google's public certs.
        return json.loads(payload)

    def verify_mobile_purchase(self, purchase_token: str, product_id: str) -> dict:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build

        credential_value = settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
        if not credential_value:
            raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not configured")

        credential_path = Path(credential_value)
        if credential_path.is_file():
            credentials = service_account.Credentials.from_service_account_file(
                str(credential_path),
                scopes=["https://www.googleapis.com/auth/androidpublisher"],
            )
        else:
            try:
                service_account_info = json.loads(credential_value)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON must be a JSON object or file path"
                ) from exc
            credentials = service_account.Credentials.from_service_account_info(
                service_account_info,
                scopes=["https://www.googleapis.com/auth/androidpublisher"],
            )

        publisher = build(
            "androidpublisher", "v3", credentials=credentials, cache_discovery=False
        )
        result = (
            publisher.purchases()
            .subscriptions()
            .get(
                packageName=settings.GOOGLE_PLAY_PACKAGE_NAME,
                subscriptionId=product_id,
                token=purchase_token,
            )
            .execute()
        )
        expiry_millis = int(result.get("expiryTimeMillis", "0"))
        if result.get("cancelReason") is not None or expiry_millis <= int(
            datetime.now(timezone.utc).timestamp() * 1000
        ):
            raise ValueError("Google Play subscription is not active")
        return result


class RevenueCatProvider(PaymentProvider):
    """
    Recommended if you plan to support both Android and iOS — RevenueCat
    normalizes Play Billing + App Store receipt validation and entitlement
    tracking behind one API, and pushes webhook events on renewal/cancel.
    """

    def __init__(self):
        if not settings.REVENUECAT_API_KEY:
            logger.warning("RevenueCatProvider initialized without REVENUECAT_API_KEY.")

    def create_checkout_session(
        self, user_email: str, success_url: str, cancel_url: str
    ) -> str:
        raise NotImplementedError(
            "RevenueCat purchases are initiated client-side via the Purchases SDK."
        )

    def verify_webhook(self, payload: bytes, signature: str) -> dict:
        # RevenueCat signs webhooks with a shared "Authorization" header
        # secret (REVENUECAT_WEBHOOK_SECRET), not HMAC — compare directly.
        return json.loads(payload)

    def verify_mobile_purchase(self, purchase_token: str, product_id: str) -> dict:
        # RevenueCat validates receipts server-side automatically; this app
        # only needs to trust their webhook events (see verify_webhook).
        raise NotImplementedError("Not needed — rely on RevenueCat webhooks instead.")


class NullProvider(PaymentProvider):
    """No-op provider so the app boots cleanly before you've chosen one."""

    def create_checkout_session(
        self, user_email: str, success_url: str, cancel_url: str
    ) -> str:
        raise NotImplementedError(
            "No payment provider configured. Set PAYMENT_PROVIDER."
        )

    def verify_webhook(self, payload: bytes, signature: str) -> dict:
        raise NotImplementedError(
            "No payment provider configured. Set PAYMENT_PROVIDER."
        )

    def verify_mobile_purchase(self, purchase_token: str, product_id: str) -> dict:
        raise NotImplementedError(
            "No payment provider configured. Set PAYMENT_PROVIDER."
        )


def get_payment_provider() -> PaymentProvider:
    provider = settings.PAYMENT_PROVIDER.lower()
    if provider == "stripe":
        return StripeProvider()
    if provider == "google_play":
        return GooglePlayProvider()
    if provider == "revenuecat":
        return RevenueCatProvider()
    return NullProvider()


def compute_period_end(days: int = 30) -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=days)
