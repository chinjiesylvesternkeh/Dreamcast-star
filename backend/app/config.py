"""
Central configuration for the DreamCast backend.

Everything here is sourced from environment variables so the exact same
container image can run in local dev, staging, and production — only the
env vars / Kubernetes secrets differ. Never hardcode secrets in this file.
"""

from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # --- App ---
    APP_NAME: str = "DreamCast API"
    APP_ENV: str = "development"  # development | staging | production
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"
    ALLOWED_ORIGINS: List[str] = ["*"]

    # --- Database ---
    DATABASE_URL: str = "postgresql://dreamcast:dreamcast@localhost:5432/dreamcast"
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20

    # --- Redis (rate limiting, caching, job queue) ---
    REDIS_URL: str = "redis://localhost:6379/0"

    # --- Auth / JWT ---
    JWT_SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24h
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # --- AI providers ---
    ANTHROPIC_API_KEY: str = ""
    AI_MODEL_NAME: str = "claude-sonnet-4-6"
    IMAGE_PROVIDER_API_KEY: str = ""  # e.g. Stability AI / Google Imagen key
    IMAGE_PROVIDER_URL: str = (
        "https://api.stability.ai/v2beta/stable-image/generate/core"
    )
    IMAGE_STORAGE_BUCKET: str = ""
    IMAGE_STORAGE_REGION: str = ""
    IMAGE_STORAGE_ENDPOINT: str = ""
    IMAGE_PUBLIC_BASE_URL: str = ""

    # --- Payments (bring-your-own keys) ---
    # This backend ships with a PaymentProvider abstraction (see
    # app/services/payment_service.py). Fill in real keys via env vars /
    # k8s secrets — no code changes required to go live.
    PAYMENT_PROVIDER: str = "stripe"  # stripe | google_play | revenuecat | none
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_PRICE_ID_MONTHLY: str = ""
    GOOGLE_PLAY_PACKAGE_NAME: str = "com.dreamcast.app"
    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: str = ""  # path or raw JSON, mounted via secret
    REVENUECAT_API_KEY: str = ""
    REVENUECAT_WEBHOOK_SECRET: str = ""

    # --- Free tier limits ---
    FREE_TIER_WEEKLY_LIMIT: int = 1
    PRO_TIER_DAILY_LIMIT: int = 10

    # --- Observability ---
    SENTRY_DSN: str = ""
    LOG_LEVEL: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()
