from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.core.deps import get_current_user
from app.database import get_db

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=schemas.UserOut)
def get_me(user: models.User = Depends(get_current_user)):
    return user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    """Permanently deletes the account with its dreams, reports and subscription record.

    Required by Google Play for apps that let users create accounts. A Google
    Play subscription is billed by Google and must be cancelled in Play — the
    app tells the user this before they confirm.
    """
    db.delete(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
