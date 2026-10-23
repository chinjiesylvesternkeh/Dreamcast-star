"""
DreamCast plan catalog — the single source of truth for what each tier
costs and unlocks.

The mobile paywall renders whatever GET /api/v1/subscriptions/plans returns,
and dream submission limits / reading depth are resolved from here, so
prices and perks only ever need to change in this file.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from app import models
from app.config import get_settings

settings = get_settings()

# A Flutterwave renewal can land a little after the period ends; keep
# access during that window so paying users are never locked out early.
RENEWAL_GRACE = timedelta(days=1)


@dataclass(frozen=True)
class Plan:
    id: str
    name: str
    price_xaf: int
    tagline: str
    features: tuple[str, ...]
    daily_limit: Optional[int] = None
    weekly_limit: Optional[int] = None
    reading_depth: str = "standard"  # standard | deep | oracle
    pattern_insights: bool = False
    highlight: Optional[str] = None

    @property
    def is_paid(self) -> bool:
        return self.price_xaf > 0


FREE = Plan(
    id="free",
    name="Free",
    price_xaf=0,
    tagline="A first glimpse.",
    weekly_limit=settings.FREE_TIER_WEEKLY_LIMIT,
    features=(
        f"{settings.FREE_TIER_WEEKLY_LIMIT} dream reading per week",
        "Shareable Dream Cards",
        "Your private dream archive",
    ),
)

LUCID = Plan(
    id="lucid",
    name="Lucid",
    price_xaf=1000,
    tagline="For the curious dreamer.",
    daily_limit=1,
    features=(
        "A dream reading every day — up to 30 a month",
        "Shareable Dream Cards for every dream",
        "Your full private dream archive",
    ),
)

MYSTIC = Plan(
    id="mystic",
    name="Mystic",
    price_xaf=2000,
    tagline="Go beneath the surface.",
    daily_limit=5,
    reading_depth="deep",
    highlight="Most popular",
    features=(
        "Up to 5 dream readings a day",
        "In-depth readings: every key symbol explained",
        "A practical reflection to carry into your day",
        "Everything in Lucid",
    ),
)

ORACLE = Plan(
    id="oracle",
    name="Oracle",
    price_xaf=5000,
    tagline="See the story your dreams are telling.",
    daily_limit=15,
    reading_depth="oracle",
    pattern_insights=True,
    highlight="Deepest insight",
    features=(
        "Up to 15 dream readings a day",
        "Pattern insights linking each dream to your recent ones",
        "Oracle-depth readings that close with a guiding question",
        "Everything in Mystic",
    ),
)

PLANS: dict[str, Plan] = {plan.id: plan for plan in (FREE, LUCID, MYSTIC, ORACLE)}
PAID_PLANS = [plan for plan in PLANS.values() if plan.is_paid]


def _as_utc(value: datetime) -> datetime:
    # SQLite hands back naive datetimes; everything is stored in UTC.
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def expire_if_lapsed(db, subscription: Optional[models.Subscription]) -> None:
    """Drops a Flutterwave subscriber back to Free once their paid month runs out.

    Flutterwave payments buy a 30-day period (renewed by webhook when a
    payment plan is configured), so lapsing is detected lazily on read.
    """
    if (
        subscription is None
        or subscription.provider != models.SubscriptionProvider.FLUTTERWAVE
        or subscription.status != models.SubscriptionStatus.ACTIVE
        or subscription.current_period_end is None
    ):
        return
    if _as_utc(subscription.current_period_end) + RENEWAL_GRACE < datetime.now(timezone.utc):
        subscription.status = models.SubscriptionStatus.FREE
        subscription.plan = FREE.id
        db.commit()


def plan_for(subscription: Optional[models.Subscription]) -> Plan:
    """The plan a subscription currently entitles its user to."""
    if subscription is None or subscription.status not in (
        models.SubscriptionStatus.ACTIVE,
        models.SubscriptionStatus.TRIAL,
    ):
        return FREE
    plan = PLANS.get(subscription.plan or "")
    if plan is None or not plan.is_paid:
        # Paid subscriptions created before tiers existed (Stripe / Play).
        return MYSTIC
    return plan
