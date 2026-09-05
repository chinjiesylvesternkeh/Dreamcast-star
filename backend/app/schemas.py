from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


# ---------- Auth ----------
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: str
    email: EmailStr
    display_name: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ---------- Dreams ----------
class DreamCreate(BaseModel):
    raw_text: str = Field(min_length=3, max_length=4000)


class DreamOut(BaseModel):
    id: str
    raw_text: str
    interpretation: Optional[str]
    mood_tags: Optional[str]
    image_url: Optional[str]
    card_headline: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ---------- Subscriptions ----------
class SubscriptionOut(BaseModel):
    status: str
    provider: str
    current_period_end: Optional[datetime]

    class Config:
        from_attributes = True


class CheckoutSessionRequest(BaseModel):
    success_url: str
    cancel_url: str


class CheckoutSessionResponse(BaseModel):
    checkout_url: str
    provider: str


class GooglePlayPurchaseVerifyRequest(BaseModel):
    purchase_token: str
    product_id: str
