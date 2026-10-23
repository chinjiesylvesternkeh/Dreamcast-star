import hmac
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app import models, schemas
from app.config import get_settings
from app.core.deps import get_current_user
from app.database import get_db
from app.plans import PAID_PLANS, PLANS, expire_if_lapsed, plan_for
from app.services import flutterwave
from app.services.payment_service import (
    compute_period_end,
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
    expire_if_lapsed(db, user.subscription)
    return _subscription_out(user.subscription)


@router.get("/plans", response_model=list[schemas.PlanOut])
def list_plans():
    """Paid plans in display order. The mobile paywall renders exactly this."""
    return [
        schemas.PlanOut(
            id=plan.id,
            name=plan.name,
            price_xaf=plan.price_xaf,
            tagline=plan.tagline,
            features=list(plan.features),
            daily_limit=plan.daily_limit,
            weekly_limit=plan.weekly_limit,
            highlight=plan.highlight,
            auto_renews=bool(flutterwave.payment_plan_id(plan)),
        )
        for plan in PAID_PLANS
    ]


@router.post("/flutterwave/checkout", response_model=schemas.CheckoutSessionResponse)
def flutterwave_checkout(
    payload: schemas.FlutterwaveCheckoutRequest,
    request: Request,
    user: models.User = Depends(get_current_user),
):
    plan = PLANS.get(payload.plan)
    if plan is None or not plan.is_paid:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown plan")
    if not flutterwave.is_configured():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Payments are not available yet. Please try again later.",
        )
    redirect_url = settings.FLW_REDIRECT_URL or str(request.url_for("flutterwave_return"))
    try:
        link = flutterwave.create_payment_link(user, plan, redirect_url)
    except Exception as exc:  # noqa: BLE001
        logger.error("Flutterwave checkout failed for %s: %s", user.id, exc)
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Couldn't start the payment. Please try again."
        )
    return schemas.CheckoutSessionResponse(checkout_url=link, provider="flutterwave")


_RETURN_PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>DreamCast</title>
<style>body{{margin:0;min-height:100vh;display:grid;place-items:center;background:#07060F;
color:#F1EDFF;font-family:Georgia,serif;text-align:center;padding:24px;box-sizing:border-box}}
h1{{font-weight:500;font-size:30px;margin:16px 0 8px}}p{{color:#9C95BC;font-family:system-ui,sans-serif;
line-height:1.5;max-width:340px;margin:0 auto}}.moon{{font-size:44px;color:#E9C98B}}</style></head>
<body><main><div class="moon">&#9790;</div><h1>{title}</h1><p>{body}</p></main></body></html>"""


@router.get("/flutterwave/return", response_class=HTMLResponse, name="flutterwave_return")
def flutterwave_return(
    transaction_id: str | None = None,
    db: Session = Depends(get_db),
):
    """Where Flutterwave sends the browser after checkout."""
    subscription = None
    if transaction_id and flutterwave.is_configured():
        try:
            subscription = flutterwave.apply_transaction(
                db, flutterwave.verify_transaction(transaction_id)
            )
        except Exception as exc:  # noqa: BLE001
            logger.error("Flutterwave verification failed for %s: %s", transaction_id, exc)

    if subscription is not None:
        plan = plan_for(subscription)
        title = f"Welcome to {plan.name}"
        body = "Your payment is confirmed and your plan is active. You can return to DreamCast now."
    else:
        title = "Payment not completed"
        body = (
            "We couldn't confirm a payment. If money left your account, it will "
            "be applied automatically within a few minutes — otherwise, try again from the app."
        )
    return HTMLResponse(_RETURN_PAGE.format(title=title, body=body))


@router.post("/webhook/flutterwave")
async def flutterwave_webhook(
    request: Request,
    db: Session = Depends(get_db),
    verif_hash: str = Header(default="", alias="verif-hash"),
):
    """Point Flutterwave Dashboard > Settings > Webhooks at this URL."""
    if not settings.FLW_WEBHOOK_SECRET or not hmac.compare_digest(
        verif_hash, settings.FLW_WEBHOOK_SECRET
    ):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid webhook signature")

    raw_body = await request.body()
    event = await request.json()
    event_type = str(event.get("event") or event.get("event.type") or "unknown")
    db.add(
        models.PaymentEvent(
            provider="flutterwave",
            event_type=event_type,
            payload=raw_body.decode("utf-8", errors="ignore"),
        )
    )
    db.commit()

    transaction_id = (event.get("data") or {}).get("id")
    if event_type == "charge.completed" and transaction_id:
        # Never trust the webhook body itself — re-verify with Flutterwave.
        flutterwave.apply_transaction(db, flutterwave.verify_transaction(str(transaction_id)))
    return {"received": True}


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
    return _subscription_out(sub)


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
