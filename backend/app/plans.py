"""
DreamCast plan catalog — the single source of truth for what each tier
unlocks and which Google Play subscription product sells it.

Prices are set per country in Play Console (base price in USD below); the
app always displays the localized price Google Play returns, never these
reference values. Dream submission limits and reading depth are resolved
from here, so perks only ever need to change in this file.
"""

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from app import models
from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

# Play can deliver a renewal shortly after the period ends; re-check with
# Google only once this window has passed so renewals never cause a blip.
RENEWAL_GRACE = timedelta(hours=12)


@dataclass(frozen=True)
class PlanCopy:
    """Customer-facing text for one plan in one language."""

    tagline: str
    features: tuple[str, ...]
    highlight: Optional[str] = None


@dataclass(frozen=True)
class Plan:
    id: str
    name: str  # brand name — the same in every language
    price_usd: str  # Play Console base price; display uses Play's localized price
    copy: dict[str, PlanCopy]  # keyed by language code (see app/i18n.py)
    product_id: str = ""  # Google Play subscription product id
    daily_limit: Optional[int] = None
    weekly_limit: Optional[int] = None
    reading_depth: str = "standard"  # standard | deep | oracle
    pattern_insights: bool = False
    recommended: bool = False  # preselected on the paywall

    @property
    def is_paid(self) -> bool:
        return bool(self.product_id)

    def copy_for(self, lang: str) -> PlanCopy:
        return self.copy.get(lang) or self.copy["en"]


_weekly = settings.FREE_TIER_WEEKLY_LIMIT

FREE = Plan(
    id="free",
    name="Free",
    price_usd="0",
    weekly_limit=_weekly,
    copy={
        "en": PlanCopy(
            tagline="A first glimpse.",
            features=(
                f"{_weekly} dream reading{'' if _weekly == 1 else 's'} per week",
                "Shareable Dream Cards",
                "Your private dream archive",
            ),
        ),
        "fr": PlanCopy(
            tagline="Un premier aperçu.",
            features=(
                f"{_weekly} lecture{'' if _weekly == 1 else 's'} de rêve par semaine",
                "Des cartes de rêve à partager",
                "Vos archives de rêves privées",
            ),
        ),
    },
)

LUCID = Plan(
    id="lucid",
    name="Lucid",
    price_usd="1.79",
    product_id="dreamcast_lucid_monthly",
    daily_limit=1,
    copy={
        "en": PlanCopy(
            tagline="For the curious dreamer.",
            features=(
                "A dream reading every day — up to 30 a month",
                "Shareable Dream Cards for every dream",
                "Your full private dream archive",
            ),
        ),
        "fr": PlanCopy(
            tagline="Pour les esprits curieux.",
            features=(
                "Une lecture de rêve chaque jour — jusqu'à 30 par mois",
                "Une carte de rêve à partager pour chaque rêve",
                "Toutes vos archives de rêves privées",
            ),
        ),
    },
)

MYSTIC = Plan(
    id="mystic",
    name="Mystic",
    price_usd="3.49",
    product_id="dreamcast_mystic_monthly",
    daily_limit=2,
    reading_depth="deep",
    recommended=True,
    copy={
        "en": PlanCopy(
            tagline="Go beneath the surface.",
            highlight="Most popular",
            features=(
                "Up to 2 dream readings a day",
                "In-depth readings: every key symbol explained",
                "A practical reflection to carry into your day",
                "Everything in Lucid",
            ),
        ),
        "fr": PlanCopy(
            tagline="Allez au-delà des apparences.",
            highlight="Le plus populaire",
            features=(
                "Jusqu'à 2 lectures de rêve par jour",
                "Des lectures approfondies : chaque symbole clé expliqué",
                "Une réflexion concrète à garder en tête dans la journée",
                "Tout ce qu'offre Lucid",
            ),
        ),
    },
)

ORACLE = Plan(
    id="oracle",
    name="Oracle",
    price_usd="8.79",
    product_id="dreamcast_oracle_monthly",
    daily_limit=3,
    reading_depth="oracle",
    pattern_insights=True,
    copy={
        "en": PlanCopy(
            tagline="See the story your dreams are telling.",
            highlight="Deepest insight",
            features=(
                "Up to 3 dream readings a day",
                "Pattern insights linking each dream to your recent ones",
                "Oracle-depth readings that close with a guiding question",
                "Everything in Mystic",
            ),
        ),
        "fr": PlanCopy(
            tagline="Découvrez l'histoire que racontent vos rêves.",
            highlight="Le plus approfondi",
            features=(
                "Jusqu'à 3 lectures de rêve par jour",
                "Des liens entre chaque rêve et vos rêves récents",
                "Des lectures Oracle qui se terminent par une question pour vous guider",
                "Tout ce qu'offre Mystic",
            ),
        ),
    },
)

PLANS: dict[str, Plan] = {plan.id: plan for plan in (FREE, LUCID, MYSTIC, ORACLE)}
PAID_PLANS = [plan for plan in PLANS.values() if plan.is_paid]

# The single-tier product sold before plans existed keeps its perks.
LEGACY_PRODUCTS = {"dreamcast_pro_monthly": MYSTIC}


def plan_for_product(product_id: str) -> Optional[Plan]:
    for plan in PAID_PLANS:
        if plan.product_id == product_id:
            return plan
    return LEGACY_PRODUCTS.get(product_id)


def as_utc(value: datetime) -> datetime:
    # SQLite hands back naive datetimes; everything is stored in UTC.
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def refresh_if_lapsed(db, subscription: Optional[models.Subscription]) -> None:
    """Re-checks a Google Play subscription with Google once its period has ended.

    Real-time developer notifications normally keep the period current; this
    is the safety net if one is missed. A renewed subscription gets its new
    expiry, a lapsed one drops back to Free. Network or configuration errors
    leave the subscription untouched rather than locking a paying user out.
    """
    if (
        subscription is None
        or subscription.provider != models.SubscriptionProvider.GOOGLE_PLAY
        or subscription.status not in (models.SubscriptionStatus.ACTIVE, models.SubscriptionStatus.TRIAL)
        or subscription.current_period_end is None
        or as_utc(subscription.current_period_end) + RENEWAL_GRACE > datetime.now(timezone.utc)
    ):
        return

    from app.services.payment_service import GooglePlayProvider, SubscriptionInactive

    plan = PLANS.get(subscription.plan or "") or MYSTIC
    try:
        result = GooglePlayProvider().verify_mobile_purchase(
            subscription.provider_subscription_id or "", plan.product_id
        )
    except SubscriptionInactive:
        subscription.status = models.SubscriptionStatus.FREE
        subscription.plan = FREE.id
        db.commit()
        return
    except Exception as exc:  # noqa: BLE001
        logger.warning("Could not re-verify Play subscription %s: %s", subscription.id, exc)
        return

    subscription.current_period_end = datetime.fromtimestamp(
        int(result["expiryTimeMillis"]) / 1000, tz=timezone.utc
    )
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
        # Paid subscriptions created before tiers existed.
        return MYSTIC
    return plan
