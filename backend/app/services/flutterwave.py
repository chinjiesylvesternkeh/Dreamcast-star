"""
Flutterwave integration for XAF subscriptions (MTN / Orange Mobile Money
and cards).

Flow:
  1. App calls POST /subscriptions/flutterwave/checkout {plan}
     -> backend creates a Flutterwave Standard payment link.
  2. User pays in the browser; Flutterwave redirects to
     GET /subscriptions/flutterwave/return, which verifies the transaction.
  3. Flutterwave ALSO calls POST /subscriptions/webhook/flutterwave
     (source of truth, and how monthly renewals arrive when a payment
     plan is configured).

Every transaction is re-verified against Flutterwave's API before any
access is granted — redirect query params and webhook bodies are never
trusted on their own.
"""

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx

from app import models
from app.config import get_settings
from app.plans import PLANS, Plan, _as_utc

settings = get_settings()
logger = logging.getLogger(__name__)

FLW_BASE = "https://api.flutterwave.com/v3"
CURRENCY = "XAF"
PERIOD = timedelta(days=30)
APPLIED_EVENT = "transaction.applied"


class FlutterwaveError(Exception):
    pass


def is_configured() -> bool:
    return bool(settings.FLW_SECRET_KEY)


def payment_plan_id(plan: Plan) -> str:
    """Flutterwave payment-plan id for recurring billing; empty means a one-off month."""
    return {
        "lucid": settings.FLW_PLAN_ID_LUCID,
        "mystic": settings.FLW_PLAN_ID_MYSTIC,
        "oracle": settings.FLW_PLAN_ID_ORACLE,
    }.get(plan.id, "")


def _headers() -> dict:
    return {"Authorization": f"Bearer {settings.FLW_SECRET_KEY}"}


def build_tx_ref(user_id: str, plan_id: str) -> str:
    return f"dc_{plan_id}_{user_id}_{uuid.uuid4().hex[:12]}"


def parse_tx_ref(tx_ref: str) -> Optional[tuple[str, str]]:
    """Returns (plan_id, user_id) from a tx_ref built by build_tx_ref."""
    parts = (tx_ref or "").split("_")
    if len(parts) != 4 or parts[0] != "dc":
        return None
    return parts[1], parts[2]


def create_payment_link(user: models.User, plan: Plan, redirect_url: str) -> str:
    payload = {
        "tx_ref": build_tx_ref(user.id, plan.id),
        "amount": plan.price_xaf,
        "currency": CURRENCY,
        "redirect_url": redirect_url,
        "payment_options": "mobilemoneyfranco,card",
        "customer": {"email": user.email, "name": user.display_name or user.email},
        "customizations": {
            "title": f"DreamCast {plan.name}",
            "description": f"{plan.name} plan — XAF {plan.price_xaf:,} per month",
        },
        "meta": {"user_id": user.id, "plan": plan.id},
    }
    flw_plan = payment_plan_id(plan)
    if flw_plan:
        payload["payment_plan"] = flw_plan

    resp = httpx.post(f"{FLW_BASE}/payments", json=payload, headers=_headers(), timeout=20)
    data = resp.json()
    if resp.status_code != 200 or data.get("status") != "success":
        raise FlutterwaveError(data.get("message", "Could not create payment link"))
    return data["data"]["link"]


def verify_transaction(transaction_id: str) -> dict:
    resp = httpx.get(
        f"{FLW_BASE}/transactions/{transaction_id}/verify", headers=_headers(), timeout=20
    )
    data = resp.json()
    if resp.status_code != 200 or data.get("status") != "success":
        raise FlutterwaveError(data.get("message", "Could not verify transaction"))
    return data["data"]


def apply_transaction(db, transaction: dict) -> Optional[models.Subscription]:
    """Grants (or extends) the plan a verified, successful transaction paid for.

    Idempotent: each Flutterwave transaction is applied at most once, so the
    redirect and the webhook can both safely deliver the same payment.
    """
    if transaction.get("status") != "successful":
        return None

    parsed = parse_tx_ref(transaction.get("tx_ref", ""))
    plan = PLANS.get(parsed[0]) if parsed else None
    if not parsed or plan is None or not plan.is_paid:
        logger.warning("Ignoring Flutterwave transaction with unknown tx_ref %s", transaction.get("tx_ref"))
        return None

    if transaction.get("currency") != CURRENCY or float(transaction.get("amount") or 0) < plan.price_xaf:
        logger.warning(
            "Flutterwave transaction %s paid %s %s for %s — below plan price",
            transaction.get("id"), transaction.get("amount"), transaction.get("currency"), plan.id,
        )
        return None

    subscription = (
        db.query(models.Subscription).filter(models.Subscription.user_id == parsed[1]).first()
    )
    if subscription is None:
        return None

    transaction_id = str(transaction.get("id"))
    already_applied = (
        db.query(models.PaymentEvent)
        .filter(
            models.PaymentEvent.provider == "flutterwave",
            models.PaymentEvent.event_type == APPLIED_EVENT,
            models.PaymentEvent.payload == transaction_id,
        )
        .first()
    )
    if already_applied:
        return subscription

    now = datetime.now(timezone.utc)
    period_start = now
    if (
        subscription.status == models.SubscriptionStatus.ACTIVE
        and subscription.plan == plan.id
        and subscription.current_period_end is not None
        and _as_utc(subscription.current_period_end) > now
    ):
        # Renewal of the same plan: stack onto the remaining time.
        period_start = _as_utc(subscription.current_period_end)

    subscription.status = models.SubscriptionStatus.ACTIVE
    subscription.plan = plan.id
    subscription.provider = models.SubscriptionProvider.FLUTTERWAVE
    subscription.provider_subscription_id = transaction_id
    subscription.current_period_end = period_start + PERIOD
    db.add(
        models.PaymentEvent(
            provider="flutterwave", event_type=APPLIED_EVENT, payload=transaction_id, processed=True
        )
    )
    db.commit()
    db.refresh(subscription)
    return subscription
