import base64
import hmac
import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.config import get_settings
from app.core.deps import get_current_user
from app.database import get_db
from app.plans import FREE, PAID_PLANS, plan_for, plan_for_product, refresh_if_lapsed
from app.services.payment_service import (
    GooglePlayProvider,
    SubscriptionInactive,
    get_payment_provider,
)

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])
logger = logging.getLogger(__name__)
settings = get_settings()


def _subscription_out(subscription: models.Subscription) -> schemas.SubscriptionOut:
    provider = subscription.provider or models.SubscriptionProvider.NONE
    return schemas.SubscriptionOut(
        status=subscription.status.value,
        provider=provider.value,
        plan=plan_for(subscription).id,
        current_period_end=subscription.current_period_end,
    )


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
    refresh_if_lapsed(db, user.subscription)
    return _subscription_out(user.subscription)


@router.get("/plans", response_model=list[schemas.PlanOut])
def list_plans():
    """Paid plans in display order, with the Play product id that sells each.

    The app shows Google Play's localized price for each product; price_usd
    is only the Play Console base price, used as a fallback label.
    """
    return [
        schemas.PlanOut(
            id=plan.id,
            name=plan.name,
            product_id=plan.product_id,
            price_usd=plan.price_usd,
            tagline=plan.tagline,
            features=list(plan.features),
            daily_limit=plan.daily_limit,
            weekly_limit=plan.weekly_limit,
            highlight=plan.highlight,
        )
        for plan in PAID_PLANS
    ]


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
    plan = plan_for_product(payload.product_id)
    if plan is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown subscription product")

    # A purchase token belongs to one DreamCast account only.
    owner = (
        db.query(models.Subscription)
        .filter(
            models.Subscription.provider_subscription_id == payload.purchase_token,
            models.Subscription.user_id != user.id,
        )
        .first()
    )
    if owner:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "This Google Play subscription is linked to another DreamCast account.",
        )

    try:
        result = GooglePlayProvider().verify_mobile_purchase(
            payload.purchase_token, payload.product_id
        )
    except SubscriptionInactive:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This subscription has expired")
    except RuntimeError as exc:
        logger.error("Play verification unavailable: %s", exc)
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "Purchase verification is unavailable"
        )

    sub = user.subscription
    sub.status = models.SubscriptionStatus.ACTIVE
    sub.plan = plan.id
    sub.provider = models.SubscriptionProvider.GOOGLE_PLAY
    sub.provider_subscription_id = payload.purchase_token
    sub.current_period_end = datetime.fromtimestamp(
        int(result["expiryTimeMillis"]) / 1000, tz=timezone.utc
    )
    db.commit()
    db.refresh(sub)
    return _subscription_out(sub)


@router.post("/webhook/google_play")
async def google_play_notification(
    request: Request, token: str = "", db: Session = Depends(get_db)
):
    """Real-time developer notifications, pushed by Google Cloud Pub/Sub.

    Configure the Pub/Sub push subscription endpoint as
      https://your-domain.com/api/v1/subscriptions/webhook/google_play?token=<GOOGLE_PLAY_RTDN_TOKEN>
    The notification only says *which* purchase changed; its state is always
    re-read from the Google Play Developer API.
    """
    if not settings.GOOGLE_PLAY_RTDN_TOKEN or not hmac.compare_digest(
        token, settings.GOOGLE_PLAY_RTDN_TOKEN
    ):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid notification token")

    envelope = await request.json()
    try:
        notification = json.loads(base64.b64decode(envelope["message"]["data"]))
    except (KeyError, TypeError, ValueError):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Malformed Pub/Sub message")

    sub_notification = notification.get("subscriptionNotification") or {}
    db.add(
        models.PaymentEvent(
            provider="google_play",
            event_type=str(sub_notification.get("notificationType", "test")),
            payload=json.dumps(notification),
        )
    )
    db.commit()

    purchase_token = sub_notification.get("purchaseToken")
    product_id = sub_notification.get("subscriptionId", "")
    subscription = (
        db.query(models.Subscription)
        .filter(models.Subscription.provider_subscription_id == purchase_token)
        .first()
        if purchase_token
        else None
    )
    if subscription is None:
        # Test notification, or a purchase the app hasn't verified yet
        # (the app's own verify call will link it).
        return {"received": True}

    try:
        result = GooglePlayProvider().verify_mobile_purchase(purchase_token, product_id)
    except SubscriptionInactive:
        subscription.status = models.SubscriptionStatus.FREE
        subscription.plan = FREE.id
    else:
        plan = plan_for_product(product_id)
        subscription.status = models.SubscriptionStatus.ACTIVE
        if plan:
            subscription.plan = plan.id
        subscription.current_period_end = datetime.fromtimestamp(
            int(result["expiryTimeMillis"]) / 1000, tz=timezone.utc
        )
    db.commit()
    return {"received": True}


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
