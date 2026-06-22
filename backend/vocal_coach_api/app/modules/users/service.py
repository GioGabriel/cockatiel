from time import time
from typing import Any

from app.core.exceptions import ApiError
from app.repositories.provider import get_user_repository


VALID_VOCAL_RANGES = [
  "soprano", "mezzo-soprano", "alto", "tenor", "baritone", "bass",
]

VALID_CATEGORIES = ["vocal_training", "do_re_mi", "breathing"]

VALID_TRAINING_GOALS = [
  "pitch_improvement",
  "breath_control",
  "tone_quality",
  "range_extension",
  "general_skill_building",
]


def upsert_user(identity: dict[str, Any]) -> dict[str, Any]:
  repository = get_user_repository()
  return repository.upsert(identity)


def get_user_profile(user_id: str) -> dict[str, Any]:
  """Get full user profile. Raises ApiError(404) if not found."""
  repository = get_user_repository()
  user = repository.get(user_id)
  if user is None:
    raise ApiError(
      code="USER_NOT_FOUND",
      message="User not found",
      status_code=404,
    )
  return user


def update_vocal_preferences(user_id: str, preferences: dict[str, Any]) -> dict[str, Any]:
  """Validate and persist vocal preferences. Returns updated profile.

  Validation: vocal_range must be one of 6 values, preferred_categories 1-3 items
  from valid catalog category IDs, training_goal one of 5 values.
  Raises ApiError(422) on invalid input, ApiError(404) if user not found.
  """
  errors: list[str] = []

  vocal_range = preferences.get("vocal_range")
  if vocal_range is not None and vocal_range not in VALID_VOCAL_RANGES:
    errors.append(
      f"vocal_range must be one of {VALID_VOCAL_RANGES}"
    )

  preferred_categories = preferences.get("preferred_categories")
  if preferred_categories is not None:
    if not isinstance(preferred_categories, list):
      errors.append("preferred_categories must be a list")
    elif len(preferred_categories) < 1 or len(preferred_categories) > 3:
      errors.append("preferred_categories must contain 1-3 items")
    else:
      invalid = [c for c in preferred_categories if c not in VALID_CATEGORIES]
      if invalid:
        errors.append(
          f"preferred_categories contains invalid values: {invalid}. "
          f"Valid values: {VALID_CATEGORIES}"
        )

  training_goal = preferences.get("training_goal")
  if training_goal is not None and training_goal not in VALID_TRAINING_GOALS:
    errors.append(
      f"training_goal must be one of {VALID_TRAINING_GOALS}"
    )

  if errors:
    raise ApiError(
      code="VALIDATION_ERROR",
      message="; ".join(errors),
      status_code=422,
    )

  repository = get_user_repository()
  user = repository.get(user_id)
  if user is None:
    raise ApiError(
      code="USER_NOT_FOUND",
      message="User not found",
      status_code=404,
    )

  updated = repository.update(user_id, {"vocal_preferences": preferences})
  return updated  # type: ignore[return-value]


def upgrade_tier(user_id: str, target_tier: str = "premium") -> dict[str, Any]:
  """Upgrade user to target tier. Idempotent. Returns updated profile.

  Sets premium_expires_at to 365 days from now (in ms).
  Raises ApiError(404) if user not found.
  """
  repository = get_user_repository()
  user = repository.get(user_id)
  if user is None:
    raise ApiError(
      code="USER_NOT_FOUND",
      message="User not found",
      status_code=404,
    )

  expires_at = int(time() * 1000) + (365 * 24 * 60 * 60 * 1000)
  updated = repository.update(user_id, {
    "access_tier": target_tier,
    "premium_expires_at": expires_at,
  })
  return updated  # type: ignore[return-value]


def downgrade_tier(user_id: str) -> dict[str, Any]:
  """Downgrade user to registered tier. Clears premium_expires_at. Returns updated profile.

  Raises ApiError(404) if user not found.
  """
  repository = get_user_repository()
  user = repository.get(user_id)
  if user is None:
    raise ApiError(
      code="USER_NOT_FOUND",
      message="User not found",
      status_code=404,
    )

  updated = repository.update(user_id, {
    "access_tier": "registered",
    "premium_expires_at": None,
  })
  return updated  # type: ignore[return-value]


def get_access_tier(user_id: str) -> str:
  """Return user's current access tier string. Returns 'guest' if user not found."""
  repository = get_user_repository()
  user = repository.get(user_id)
  if user is None:
    return "guest"
  return user.get("access_tier", "guest")
