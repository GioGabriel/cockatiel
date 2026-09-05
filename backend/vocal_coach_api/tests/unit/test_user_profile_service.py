"""Unit tests for the user profile service module."""
import os

os.environ["AUTH_BYPASS"] = "true"
os.environ["FIRESTORE_ENABLED"] = "false"
os.environ["OPENROUTER_ENABLED"] = "false"
os.environ["AUDIO_SNIPPET_STORAGE_BACKEND"] = "local"
os.environ["AUDIO_SNIPPET_LOCAL_DIR"] = "/tmp/vocal-coach-audio-test"
os.environ["AUDIO_SNIPPET_RETENTION_DAYS"] = "30"

import pytest

from app.core.exceptions import ApiError
from app.modules.users.service import (
  downgrade_tier,
  get_access_tier,
  get_retention_days,
  get_user_profile,
  update_vocal_preferences,
  upgrade_tier,
  upgrade_to_premium,
  upsert_user,
)
from app.repositories.provider import reset_repository_bundle


@pytest.fixture(autouse=True)
def _reset() -> None:
  reset_repository_bundle()
  yield  # type: ignore[misc]
  reset_repository_bundle()


def _create_user(uid: str = "u1") -> dict:
  return upsert_user({"uid": uid, "email": "a@b.com", "name": "Test"})


class TestGetUserProfile:
  def test_returns_profile_for_existing_user(self) -> None:
    _create_user("u1")
    profile = get_user_profile("u1")
    assert profile["uid"] == "u1"
    assert profile["email"] == "a@b.com"
    assert profile["access_tier"] == "registered"
    assert profile["vocal_preferences"] is None
    assert "created_at" in profile
    assert "updated_at" in profile

  def test_raises_404_for_missing_user(self) -> None:
    with pytest.raises(ApiError) as exc_info:
      get_user_profile("nonexistent")
    assert exc_info.value.status_code == 404
    assert exc_info.value.code == "USER_NOT_FOUND"


class TestUpdateVocalPreferences:
  def test_returns_canonical_profile_when_legacy_repository_response_omits_access_tier(
    self,
    monkeypatch: pytest.MonkeyPatch,
  ) -> None:
    """Legacy Firestore profiles must still satisfy the profile response contract."""

    class LegacyUserRepository:
      def __init__(self) -> None:
        self.user = {
          "uid": "u1",
          "email": "a@b.com",
          "name": "Test",
          "vocal_preferences": None,
        }

      def get(self, uid: str) -> dict | None:
        return self.user if uid == "u1" else None

      def update(self, uid: str, updates: dict) -> dict | None:
        self.user.update(updates)
        # Simulate a legacy Firestore document that has no access_tier field.
        return {key: value for key, value in self.user.items() if key != "access_tier"}

    repository = LegacyUserRepository()
    monkeypatch.setattr(
      "app.modules.users.service.get_user_repository",
      lambda: repository,
    )

    result = update_vocal_preferences(
      "u1",
      {
        "vocal_range": "tenor",
        "preferred_categories": ["vocal_training"],
        "training_goal": "pitch_improvement",
      },
    )

    assert result["access_tier"] == "registered"
    assert result["vocal_preferences"]["vocal_range"] == "tenor"

  def test_valid_preferences_are_persisted(self) -> None:
    _create_user("u1")
    prefs = {
      "vocal_range": "tenor",
      "preferred_categories": ["vocal_training", "breathing"],
      "training_goal": "pitch_improvement",
    }
    result = update_vocal_preferences("u1", prefs)
    assert result["vocal_preferences"] == prefs

  def test_voice_calibration_is_persisted_without_raw_audio(self) -> None:
    _create_user("u1")
    calibration = {
      "voice_type": "alto",
      "confidence": 0.74,
      "average_frequency_hz": 277.2,
      "lowest_frequency_hz": 174.6,
      "highest_frequency_hz": 523.3,
      "sample_count": 64,
      "calibrated_at_ms": 1760000000000,
    }
    result = update_vocal_preferences(
      "u1",
      {
        "vocal_range": "alto",
        "preferred_categories": ["vocal_training"],
        "training_goal": "general_skill_building",
        "voice_calibration": calibration,
      },
    )
    assert result["vocal_preferences"]["voice_calibration"] == calibration
    assert "audio" not in result["vocal_preferences"]["voice_calibration"]

  def test_voice_calibration_with_reversed_range_raises_422(self) -> None:
    _create_user("u1")
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences(
        "u1",
        {
          "vocal_range": "alto",
          "preferred_categories": ["vocal_training"],
          "training_goal": "general_skill_building",
          "voice_calibration": {
            "voice_type": "alto",
            "confidence": 0.74,
            "average_frequency_hz": 277.2,
            "lowest_frequency_hz": 523.3,
            "highest_frequency_hz": 174.6,
            "sample_count": 64,
            "calibrated_at_ms": 1760000000000,
          },
        },
      )
    assert exc_info.value.status_code == 422

  def test_invalid_vocal_range_raises_422(self) -> None:
    _create_user("u1")
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences("u1", {"vocal_range": "unknown"})
    assert exc_info.value.status_code == 422
    assert exc_info.value.code == "VALIDATION_ERROR"

  def test_too_many_categories_raises_422(self) -> None:
    _create_user("u1")
    prefs = {
      "preferred_categories": ["vocal_training", "do_re_mi", "breathing", "extra"],
    }
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences("u1", prefs)
    assert exc_info.value.status_code == 422

  def test_empty_categories_raises_422(self) -> None:
    _create_user("u1")
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences("u1", {"preferred_categories": []})
    assert exc_info.value.status_code == 422

  def test_invalid_category_raises_422(self) -> None:
    _create_user("u1")
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences("u1", {"preferred_categories": ["invalid_cat"]})
    assert exc_info.value.status_code == 422

  def test_invalid_training_goal_raises_422(self) -> None:
    _create_user("u1")
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences("u1", {"training_goal": "nonsense"})
    assert exc_info.value.status_code == 422

  def test_raises_404_for_missing_user(self) -> None:
    with pytest.raises(ApiError) as exc_info:
      update_vocal_preferences("nope", {"vocal_range": "tenor"})
    assert exc_info.value.status_code == 404


class TestUpgradeTier:
  def test_upgrades_to_premium(self) -> None:
    _create_user("u1")
    result = upgrade_tier("u1")
    assert result["access_tier"] == "premium"

  def test_idempotent_upgrade(self) -> None:
    _create_user("u1")
    upgrade_tier("u1")
    result = upgrade_tier("u1")
    assert result["access_tier"] == "premium"

  def test_raises_404_for_missing_user(self) -> None:
    with pytest.raises(ApiError) as exc_info:
      upgrade_tier("nope")
    assert exc_info.value.status_code == 404


class TestDowngradeTier:
  def test_downgrades_to_registered(self) -> None:
    _create_user("u1")
    upgrade_tier("u1")
    result = downgrade_tier("u1")
    assert result["access_tier"] == "registered"

  def test_raises_404_for_missing_user(self) -> None:
    with pytest.raises(ApiError) as exc_info:
      downgrade_tier("nope")
    assert exc_info.value.status_code == 404


class TestGetAccessTier:
  def test_returns_tier_for_existing_user(self) -> None:
    _create_user("u1")
    assert get_access_tier("u1") == "registered"

  def test_returns_guest_for_missing_user(self) -> None:
    assert get_access_tier("nonexistent") == "guest"

  def test_reflects_upgrade(self) -> None:
    _create_user("u1")
    upgrade_tier("u1")
    assert get_access_tier("u1") == "premium"


class TestUpgradeToPremium:
  def test_upgrades_to_premium(self) -> None:
    _create_user("u1")
    result = upgrade_to_premium("u1")
    assert result["access_tier"] == "premium"
    assert result["premium_expires_at"] is not None

  def test_raises_404_for_missing_user(self) -> None:
    with pytest.raises(ApiError) as exc_info:
      upgrade_to_premium("nope")
    assert exc_info.value.status_code == 404


class TestGetRetentionDays:
  def test_premium_365(self) -> None:
    assert get_retention_days("premium") == 365

  def test_registered_90(self) -> None:
    assert get_retention_days("registered") == 90

  def test_guest_0(self) -> None:
    assert get_retention_days("guest") == 0

  def test_unknown_tier_0(self) -> None:
    assert get_retention_days("unknown") == 0


class TestDowngradePreservesPremiumData:
  def test_preserves_premium_expires_at(self) -> None:
    _create_user("u1")
    upgraded = upgrade_tier("u1")
    expires = upgraded["premium_expires_at"]
    downgraded = downgrade_tier("u1")
    assert downgraded["access_tier"] == "registered"
    assert downgraded["premium_expires_at"] == expires
