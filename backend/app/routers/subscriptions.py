import logging

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
        result = provider.verify_mobile_purchase(payload.purchase_token, payload.product_id)
    except NotImplementedError as exc:
        raise HTTPException(status.HTTP_501_NOT_IMPLEMENTED, str(exc))

    sub = user.subscription
    sub.status = models.SubscriptionStatus.ACTIVE
    sub.provider = models.SubscriptionProvider.GOOGLE_PLAY
    sub.provider_subscription_id = payload.purchase_token
    sub.current_period_end = compute_period_end(30)
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
    provider = get_payment_provider()

    try:
        event = provider.verify_webhook(raw_body, stripe_signature or "")
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

    # TODO: dispatch on event["type"] to update the matching Subscription row:
    #   - checkout.session.completed / customer.subscription.updated -> ACTIVE
    #   - customer.subscription.deleted -> CANCELED
    #   - invoice.payment_failed -> PAST_DUE
    # Left intentionally minimal here since exact event shapes differ per
    # provider — wire this up once you've picked and configured one.
    logger.info("Received %s webhook event: %s", provider_name, event.get("type"))

    return {"received": True}
