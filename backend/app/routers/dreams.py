from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.core.deps import get_current_user
from app.database import get_db
from app.plans import Plan, expire_if_lapsed, plan_for
from app.services.ai_service import interpret_dream
from app.services.image_service import generate_dream_image

router = APIRouter(prefix="/dreams", tags=["dreams"])


def _check_rate_limit(db: Session, user: models.User) -> Plan:
    """Enforces the user's plan limits and returns the plan they're on."""
    expire_if_lapsed(db, user.subscription)
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
                "You've used this week's free reading. Choose a plan for daily readings."
                if not plan.is_paid
                else f"You've used today's {limit} {plan.name} readings. Upgrade for more, or come back tomorrow."
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
):
    plan = _check_rate_limit(db, user)

    result = interpret_dream(
        payload.raw_text,
        depth=plan.reading_depth,
        recent_dreams=_recent_dreams(db, user) if plan.pattern_insights else None,
    )
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
