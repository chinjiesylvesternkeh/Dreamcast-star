import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.core.deps import get_current_user
from app.database import get_db
from app.services.payment_service import (
    compute_period_end,
    get_payment_provider,
)

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])
logger = logging.getLogger(__name__)


def _event_object(event: dict) -> dict:
    return event.get("data", {}).get("object", event.get("event", event))


def _subscription_status(event_type: str, event_object: dict):
    if event_type in {"checkout.session.completed", "customer.subscription.created"}:
        return models.SubscriptionStatus.ACTIVE
    if event_type in {
        "customer.subscription.deleted",
        "subscription_cancelled",
        "CANCELLATION",
    }:
        return models.SubscriptionStatus.CANCELED
    if event_type in {"invoice.payment_failed", "subscription_paused", "PAYMENT_ISSUE"}:
        return models.SubscriptionStatus.PAST_DUE
    provider_status = event_object.get("status")
    return {
        "active": models.SubscriptionStatus.ACTIVE,
        "trialing": models.SubscriptionStatus.TRIAL,
        "past_due": models.SubscriptionStatus.PAST_DUE,
        "canceled": models.SubscriptionStatus.CANCELED,
        "unpaid": models.SubscriptionStatus.PAST_DUE,
    }.get(provider_status)


def _find_subscription(db: Session, provider_name: str, event_object: dict):
    provider = getattr(models.SubscriptionProvider, provider_name.upper(), None)
    if provider:
        query = db.query(models.Subscription).filter(
            (models.Subscription.provider == provider)
            | (models.Subscription.provider == models.SubscriptionProvider.NONE)
        )
    else:
        query = db.query(models.Subscription)

    provider_ids = [
        event_object.get("subscription"),
        event_object.get("subscription_id"),
        event_object.get("purchaseToken"),
        event_object.get("id"),
    ]
    for provider_id in provider_ids:
        if provider_id:
            subscription = query.filter(
                (models.Subscription.provider_subscription_id == provider_id)
                | (models.Subscription.provider_customer_id == provider_id)
            ).first()
            if subscription:
                return subscription

    email = event_object.get("customer_email") or event_object.get("email")
    customer_details = event_object.get("customer_details") or {}
    email = email or customer_details.get("email")
    if email:
        return (
            query.join(models.Subscription.user)
            .filter(models.User.email == email)
            .first()
        )
    return None


@router.get("/me", response_model=schemas.SubscriptionOut)
def my_subscription(
    db: Session = Depends(get_db), user: models.User = Depends(get_current_user)
):
    if not user.subscription:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No subscription record")
    return user.subscription


@router.post("/checkout", response_model=schemas.CheckoutSessionResponse)
def create_checkout(
    payload: schemas.CheckoutSessionRequest,
    user: models.User = Depends(get_current_user),
):
    """
    Web/Stripe checkout entry point. For native Android purchases, the
    mobile app calls Google Play Billing directly instead of this endpoint —
    see mobile/lib/services/billing_service.dart — then hits
    /subscriptions/verify-mobile-purchase.
    """
    provider = get_payment_provider()
    url = provider.create_checkout_session(
        user_email=user.email,
        success_url=payload.success_url,
        cancel_url=payload.cancel_url,
    )
    return schemas.CheckoutSessionResponse(checkout_url=url, provider="stripe")


@router.post("/verify-mobile-purchase", response_model=schemas.SubscriptionOut)
def verify_mobile_purchase(
    payload: schemas.GooglePlayPurchaseVerifyRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    provider = get_payment_provider()
    try:
        result = provider.verify_mobile_purchase(
            payload.purchase_token, payload.product_id
        )
    except NotImplementedError as exc:
        raise HTTPException(status.HTTP_501_NOT_IMPLEMENTED, str(exc))

    sub = user.subscription
    sub.status = models.SubscriptionStatus.ACTIVE
    sub.provider = models.SubscriptionProvider.GOOGLE_PLAY
    sub.provider_subscription_id = payload.purchase_token
    expiry_millis = result.get("expiryTimeMillis")
    sub.current_period_end = (
        datetime.fromtimestamp(int(expiry_millis) / 1000, tz=timezone.utc)
        if expiry_millis
        else compute_period_end(30)
    )
    db.commit()
    db.refresh(sub)
    return sub


@router.post("/webhook/{provider_name}")
async def payment_webhook(
    provider_name: str,
    request: Request,
    db: Session = Depends(get_db),
    stripe_signature: str = Header(default=None, alias="stripe-signature"),
):
    """
    Single webhook entry point for all providers. Point your provider's
    dashboard at:
      https://your-domain.com/api/v1/subscriptions/webhook/stripe
      https://your-domain.com/api/v1/subscriptions/webhook/google_play
      https://your-domain.com/api/v1/subscriptions/webhook/revenuecat
    """
    raw_body = await request.body()
    payment_provider = get_payment_provider()
    provider = getattr(models.SubscriptionProvider, provider_name.upper(), None)

    try:
        event = payment_provider.verify_webhook(raw_body, stripe_signature or "")
    except Exception as exc:  # noqa: BLE001
        logger.warning("Webhook verification failed for %s: %s", provider_name, exc)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid webhook signature")

    # Audit log every event before acting on it.
    db.add(
        models.PaymentEvent(
            provider=provider_name,
            event_type=str(event.get("type", "unknown")),
            payload=raw_body.decode("utf-8", errors="ignore"),
        )
    )
    db.commit()

    event_type = str(event.get("type", "unknown"))
    event_object = _event_object(event)
    subscription = _find_subscription(db, provider_name, event_object)
    new_status = _subscription_status(event_type, event_object)
    if subscription and new_status:
        subscription.status = new_status
        if provider:
            subscription.provider = provider
        provider_id = (
            event_object.get("subscription")
            or event_object.get("subscription_id")
            or event_object.get("purchaseToken")
            or event_object.get("id")
        )
        if provider_id and not subscription.provider_subscription_id:
            subscription.provider_subscription_id = provider_id
        period_end = event_object.get("current_period_end")
        if period_end:
            subscription.current_period_end = datetime.fromtimestamp(
                int(period_end), tz=timezone.utc
            )
        payment_event = (
            db.query(models.PaymentEvent)
            .order_by(models.PaymentEvent.received_at.desc())
            .first()
        )
        if payment_event:
            payment_event.processed = True
        db.commit()
    logger.info("Received %s webhook event: %s", provider_name, event.get("type"))

    return {"received": True}
