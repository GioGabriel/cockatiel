from time import time
from typing import Any
from numbers import Real

from app.core.exceptions import ApiError
from app.repositories.provider import get_user_repository


VALID_VOCAL_RANGES = [
  "soprano", "mezzo-soprano", "alto", "tenor", "baritone", "bass",
]

VALID_CATEGORIES = ["vocal_training", "do_re_mi", "breathing", "karaoke"]

VALID_TRAINING_GOALS = [
  "pitch_improvement",
  "breath_control",
  "tone_quality",
  "range_extension",
  "general_skill_building",
]

_VOICE_CALIBRATION_FIELDS = {
  "voice_type",
  "confidence",
  "average_frequency_hz",
  "lowest_frequency_hz",
  "highest_frequency_hz",
  "sample_count",
  "calibrated_at_ms",
}


def upsert_user(identity: dict[str, Any]) -> dict[str, Any]:
  repository = get_user_repository()
  if "access_tier" not in identity:
    identity["access_tier"] = "registered"
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
  if "access_tier" not in user:
    user["access_tier"] = "registered"
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

  voice_calibration = preferences.get("voice_calibration")
  if voice_calibration is not None:
    if not isinstance(voice_calibration, dict):
      errors.append("voice_calibration must be an object")
    else:
      missing = sorted(_VOICE_CALIBRATION_FIELDS - set(voice_calibration))
      unknown = sorted(set(voice_calibration) - _VOICE_CALIBRATION_FIELDS)
      if missing:
        errors.append(f"voice_calibration is missing fields: {missing}")
      if unknown:
        errors.append(f"voice_calibration contains unknown fields: {unknown}")

      calibration_voice_type = voice_calibration.get("voice_type")
      if calibration_voice_type not in VALID_VOCAL_RANGES:
        errors.append(
          f"voice_calibration.voice_type must be one of {VALID_VOCAL_RANGES}"
        )

      for field_name in (
        "confidence",
        "average_frequency_hz",
        "lowest_frequency_hz",
        "highest_frequency_hz",
      ):
        value = voice_calibration.get(field_name)
        if not isinstance(value, Real) or isinstance(value, bool):
          errors.append(f"voice_calibration.{field_name} must be numeric")

      confidence = voice_calibration.get("confidence")
      if isinstance(confidence, Real) and not isinstance(confidence, bool) and not 0 <= confidence <= 1:
        errors.append("voice_calibration.confidence must be between 0 and 1")

      low_hz = voice_calibration.get("lowest_frequency_hz")
      high_hz = voice_calibration.get("highest_frequency_hz")
      average_hz = voice_calibration.get("average_frequency_hz")
      if all(isinstance(value, Real) and not isinstance(value, bool) for value in (low_hz, high_hz, average_hz)):
        if low_hz <= 0 or high_hz <= 0 or average_hz <= 0:
          errors.append("voice_calibration frequencies must be positive")
        if low_hz > high_hz:
          errors.append("voice_calibration.lowest_frequency_hz must not exceed highest_frequency_hz")
        if not low_hz <= average_hz <= high_hz:
          errors.append("voice_calibration.average_frequency_hz must be between the lowest and highest frequencies")

      sample_count = voice_calibration.get("sample_count")
      if not isinstance(sample_count, int) or isinstance(sample_count, bool) or sample_count < 1:
        errors.append("voice_calibration.sample_count must be a positive integer")

      calibrated_at_ms = voice_calibration.get("calibrated_at_ms")
      if not isinstance(calibrated_at_ms, int) or isinstance(calibrated_at_ms, bool) or calibrated_at_ms < 0:
        errors.append("voice_calibration.calibrated_at_ms must be a non-negative integer")

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

  repository.update(user_id, {"vocal_preferences": preferences})

  # Read the canonical profile after the write instead of returning the
  # repository's raw update result. Firestore documents created before
  # access_tier was introduced may omit that field, while UserProfileOut
  # requires it. get_user_profile also applies the registered default for
  # those legacy documents.
  return get_user_profile(user_id)


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
  repository.update(user_id, {
    "access_tier": target_tier,
    "premium_expires_at": expires_at,
  })
  return get_user_profile(user_id)


def upgrade_to_premium(user_id: str) -> dict[str, Any]:
  """Upgrade user to premium tier. Convenience wrapper around upgrade_tier.

  Sets premium_expires_at to 365 days from now (in ms).
  Raises ApiError(404) if user not found.
  """
  return upgrade_tier(user_id, target_tier="premium")


def downgrade_tier(user_id: str) -> dict[str, Any]:
  """Downgrade user to registered tier. Preserves premium_expires_at for
  historical retention policy. Returns updated profile.

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

  repository.update(user_id, {
    "access_tier": "registered",
  })
  return get_user_profile(user_id)


def get_access_tier(user_id: str) -> str:
  """Return user's current access tier string. Returns 'guest' if user not found."""
  repository = get_user_repository()
  user = repository.get(user_id)
  if user is None:
    return "guest"
  return user.get("access_tier", "guest")


def get_retention_days(tier: str) -> int:
  """Return the session retention window in days based on access tier.

  Premium: 365 days
  Registered: 90 days
  Guest: 0 days (no session storage)
  """
  if tier == "premium":
    return 365
  if tier == "registered":
    return 90
  return 0
