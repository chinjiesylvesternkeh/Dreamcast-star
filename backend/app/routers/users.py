import logging

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.core.deps import get_current_user
from app.database import get_db
from app.i18n import get_language, t
from app.services.image_service import delete_dream_images

router = APIRouter(prefix="/users", tags=["users"])
logger = logging.getLogger(__name__)


@router.get("/me", response_model=schemas.UserOut)
def get_me(user: models.User = Depends(get_current_user)):
    return user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    lang: str = Depends(get_language),
):
    """Permanently deletes the account, its dreams, Dream Card images, reports and subscription record.

    Required by Google Play for apps that let users create accounts. A Google
    Play subscription is billed by Google and must be cancelled in Play — the
    app tells the user this before they confirm.
    """
    try:
        delete_dream_images([dream.image_url for dream in user.dreams])
    except Exception as exc:  # noqa: BLE001
        # Keep the account so the user can retry; nothing has been deleted yet.
        logger.error("Could not delete Dream Card images for %s: %s", user.id, exc)
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, t("delete_failed", lang)
        )
    db.delete(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
