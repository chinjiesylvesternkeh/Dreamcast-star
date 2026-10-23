import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import get_settings
from app.database import Base, SessionLocal, engine
from app.routers import auth, dreams, subscriptions, users

settings = get_settings()

logging.basicConfig(level=settings.LOG_LEVEL)
logger = logging.getLogger(__name__)

if settings.SENTRY_DSN:
    import sentry_sdk

    sentry_sdk.init(dsn=settings.SENTRY_DSN, environment=settings.APP_ENV, traces_sample_rate=0.2)


def _check_production_config() -> None:
    """Refuse to serve real users with development defaults."""
    if settings.APP_ENV != "production":
        return
    if settings.JWT_SECRET_KEY == "CHANGE_ME_IN_PRODUCTION" or len(settings.JWT_SECRET_KEY) < 32:
        raise RuntimeError("Set JWT_SECRET_KEY to a random secret of at least 32 characters in production")
    if settings.DATABASE_URL.startswith("sqlite"):
        raise RuntimeError("Production must use PostgreSQL, not SQLite")
    if not settings.ANTHROPIC_API_KEY:
        logger.error("ANTHROPIC_API_KEY is not set — dream readings will fail until it is configured")


@asynccontextmanager
async def lifespan(app: FastAPI):
    _check_production_config()
    # In production, run migrations via Alembic (see backend/alembic/) as a
    # separate CI/CD step instead of create_all(). create_all() is fine for
    # local dev / first boot only.
    if settings.APP_ENV == "development":
        Base.metadata.create_all(bind=engine)
    logger.info("DreamCast API starting in %s mode", settings.APP_ENV)
    yield
    logger.info("DreamCast API shutting down")


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    docs_url="/docs" if settings.APP_ENV != "production" else None,
    redoc_url=None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(users.router, prefix=settings.API_V1_PREFIX)
app.include_router(dreams.router, prefix=settings.API_V1_PREFIX)
app.include_router(subscriptions.router, prefix=settings.API_V1_PREFIX)


@app.get("/healthz", tags=["ops"])
def liveness():
    """Kubernetes liveness probe — process is up."""
    return {"status": "ok"}


@app.get("/readyz", tags=["ops"])
def readiness():
    """Kubernetes readiness probe — DB is reachable."""
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        return {"status": "ready"}
    except Exception as exc:  # noqa: BLE001
        logger.error("Readiness check failed: %s", exc)
        return {"status": "not_ready", "error": str(exc)}


@app.get("/", tags=["ops"])
def root():
    return {"service": settings.APP_NAME, "status": "running"}
