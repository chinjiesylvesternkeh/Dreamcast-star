from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.config import get_settings
from app.core.deps import get_current_user
from app.database import get_db
from app.services.ai_service import interpret_dream
from app.services.image_service import generate_dream_image

router = APIRouter(prefix="/dreams", tags=["dreams"])
settings = get_settings()


def _check_rate_limit(db: Session, user: models.User):
    """Enforces free vs paid daily/weekly submission limits."""
    is_pro = (
        user.subscription is not None
        and user.subscription.status
        in (models.SubscriptionStatus.ACTIVE, models.SubscriptionStatus.TRIAL)
    )

    if is_pro:
        window_start = datetime.now(timezone.utc) - timedelta(days=1)
        limit = settings.PRO_TIER_DAILY_LIMIT
    else:
        window_start = datetime.now(timezone.utc) - timedelta(days=7)
        limit = settings.FREE_TIER_WEEKLY_LIMIT

    count = (
        db.query(func.count(models.Dream.id))
        .filter(models.Dream.user_id == user.id, models.Dream.created_at >= window_start)
        .scalar()
    )
    if count >= limit:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                "You've reached your dream interpretation limit. "
                "Upgrade to DreamCast Pro for unlimited daily interpretations."
                if not is_pro
                else "Daily limit reached — try again tomorrow."
            ),
        )


@router.post("", response_model=schemas.DreamOut, status_code=status.HTTP_201_CREATED)
def submit_dream(
    payload: schemas.DreamCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _check_rate_limit(db, user)

    result = interpret_dream(payload.raw_text)
    image_url = generate_dream_image(prompt_hint=result.card_headline or payload.raw_text[:120])

    dream = models.Dream(
        user_id=user.id,
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
):
    dream = (
        db.query(models.Dream)
        .filter(models.Dream.id == dream_id, models.Dream.user_id == user.id)
        .first()
    )
    if not dream:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Dream not found")
    return dream
