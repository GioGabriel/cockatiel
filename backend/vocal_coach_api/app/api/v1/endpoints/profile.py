from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import UserProfileOut, VocalPreferencesIn
from app.modules.users.service import (
  get_user_profile,
  update_vocal_preferences,
  upgrade_to_premium,
)

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=UserProfileOut)
def fetch_profile(current_user: dict = Depends(get_current_user)) -> UserProfileOut:
  """Get full user profile with access tier and vocal preferences."""
  profile = get_user_profile(current_user["uid"])
  return UserProfileOut.model_validate(profile)


@router.put("/preferences", response_model=UserProfileOut)
def update_preferences(
  payload: VocalPreferencesIn,
  current_user: dict = Depends(get_current_user),
) -> UserProfileOut:
  """Validate and update vocal preferences."""
  updated = update_vocal_preferences(current_user["uid"], payload.model_dump())
  return UserProfileOut.model_validate(updated)


@router.post("/tier/upgrade", response_model=UserProfileOut)
def upgrade_tier(current_user: dict = Depends(get_current_user)) -> UserProfileOut:
  """Upgrade user to premium tier."""
  updated = upgrade_to_premium(current_user["uid"])
  return UserProfileOut.model_validate(updated)
