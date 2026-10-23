from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.core.deps import get_current_user
from app.config import get_settings
from app.database import get_db
from app.i18n import get_language, t
from app.plans import Plan, plan_for, refresh_if_lapsed
from app.services.ai_service import ReadingUnavailable, interpret_dream
from app.services.image_service import generate_dream_image

router = APIRouter(prefix="/dreams", tags=["dreams"])
settings = get_settings()


def _check_rate_limit(db: Session, user: models.User, lang: str) -> Plan:
    """Enforces the user's plan limits and returns the plan they're on."""
    refresh_if_lapsed(db, user.subscription)
    plan = plan_for(user.subscription)

    if plan.daily_limit is not None:
        window_start = datetime.now(timezone.utc) - timedelta(days=1)
        limit = plan.daily_limit
    else:
        window_start = datetime.now(timezone.utc) - timedelta(days=7)
        limit = plan.weekly_limit or 0

    count = (
        db.query(func.count(models.Dream.id))
        .filter(models.Dream.user_id == user.id, models.Dream.created_at >= window_start)
        .scalar()
    )
    if count >= limit:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                t("free_limit_reached", lang)
                if not plan.is_paid
                else t("plan_limit_reached", lang, limit=limit, plan=plan.name)
            ),
        )
    return plan


def _recent_dreams(db: Session, user: models.User, limit: int = 10) -> list[models.Dream]:
    return (
        db.query(models.Dream)
        .filter(models.Dream.user_id == user.id)
        .order_by(models.Dream.created_at.desc())
        .limit(limit)
        .all()
    )


@router.post("", response_model=schemas.DreamOut, status_code=status.HTTP_201_CREATED)
def submit_dream(
    payload: schemas.DreamCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    lang: str = Depends(get_language),
):
    plan = _check_rate_limit(db, user, lang)
    user_id = user.id
    recent = (
        [
            SimpleNamespace(
                created_at=d.created_at, card_headline=d.card_headline, raw_text=d.raw_text, mood_tags=d.mood_tags
            )
            for d in _recent_dreams(db, user)
        ]
        if plan.pattern_insights
        else None
    )
    # Hand the database connection back to the pool while the Oracle writes —
    # a reading can take over a minute, and Cloud SQL connections are scarce.
    db.commit()

    try:
        result = interpret_dream(
            payload.raw_text,
            depth=plan.reading_depth,
            recent_dreams=recent,
            language=lang,
            model=settings.AI_MODEL_PAID if plan.is_paid else settings.AI_MODEL_FREE,
        )
    except ReadingUnavailable:
        # Not counted against the plan's limit: no dream is saved.
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, t("reading_unavailable", lang))
    image_url = generate_dream_image(
        prompt_hint=result.image_prompt or result.card_headline or payload.raw_text[:120]
    )

    dream = models.Dream(
        user_id=user_id,
        raw_text=payload.raw_text,
        interpretation=result.interpretation,
        mood_tags=",".join(result.mood_tags),
        card_headline=result.card_headline,
        image_url=image_url,
    )
    db.add(dream)
    db.commit()
    db.refresh(dream)
    return dream


@router.get("", response_model=list[schemas.DreamOut])
def list_dreams(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    limit: int = 50,
    offset: int = 0,
):
    return (
        db.query(models.Dream)
        .filter(models.Dream.user_id == user.id)
        .order_by(models.Dream.created_at.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )


@router.get("/{dream_id}", response_model=schemas.DreamOut)
def get_dream(
    dream_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    lang: str = Depends(get_language),
):
    dream = (
        db.query(models.Dream)
        .filter(models.Dream.id == dream_id, models.Dream.user_id == user.id)
        .first()
    )
    if not dream:
        raise HTTPException(status.HTTP_404_NOT_FOUND, t("dream_not_found", lang))
    return dream


@router.post("/{dream_id}/report", status_code=status.HTTP_201_CREATED)
def report_dream(
    dream_id: str,
    payload: schemas.DreamReportCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    lang: str = Depends(get_language),
):
    """Flags an AI-generated reading or image for review."""
    dream = (
        db.query(models.Dream)
        .filter(models.Dream.id == dream_id, models.Dream.user_id == user.id)
        .first()
    )
    if not dream:
        raise HTTPException(status.HTTP_404_NOT_FOUND, t("dream_not_found", lang))
    db.add(models.DreamReport(dream_id=dream.id, reason=payload.reason, details=payload.details))
    db.commit()
    return {"reported": True}
