import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


def gen_uuid():
    return str(uuid.uuid4())


class SubscriptionStatus(str, enum.Enum):
    FREE = "free"
    ACTIVE = "active"
    PAST_DUE = "past_due"
    CANCELED = "canceled"
    TRIAL = "trial"


class SubscriptionProvider(str, enum.Enum):
    STRIPE = "stripe"
    GOOGLE_PLAY = "google_play"
    REVENUECAT = "revenuecat"
    NONE = "none"


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    is_active = Column(Boolean, default=True)

    dreams = relationship("Dream", back_populates="owner", cascade="all, delete-orphan")
    subscription = relationship(
        "Subscription", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class Dream(Base):
    __tablename__ = "dreams"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    raw_text = Column(Text, nullable=False)
    interpretation = Column(Text, nullable=True)
    mood_tags = Column(String(255), nullable=True)  # comma-separated, kept simple on purpose
    image_url = Column(String(500), nullable=True)
    card_headline = Column(String(280), nullable=True)  # the shareable one-liner
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner = relationship("User", back_populates="dreams")


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), unique=True, nullable=False)
    status = Column(Enum(SubscriptionStatus), default=SubscriptionStatus.FREE, nullable=False)
    provider = Column(Enum(SubscriptionProvider), default=SubscriptionProvider.NONE)
    provider_customer_id = Column(String(255), nullable=True)  # Stripe customer id, etc.
    provider_subscription_id = Column(String(255), nullable=True)
    current_period_end = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="subscription")


class PaymentEvent(Base):
    """Raw audit log of every webhook event received from a payment provider.

    Keeping the raw payload lets you replay/debug billing issues later —
    critical once real money is involved.
    """

    __tablename__ = "payment_events"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    provider = Column(String(50), nullable=False)
    event_type = Column(String(100), nullable=False)
    payload = Column(Text, nullable=False)
    received_at = Column(DateTime(timezone=True), server_default=func.now())
    processed = Column(Boolean, default=False)
