from fastapi import APIRouter, Depends, File, Form, UploadFile

from app.api.v1.dependencies import get_current_user, get_current_user_or_guest
from app.api.v1.schemas import (
  KaraokeCatalogOut,
  KaraokeCatalogPreviewOut,
  KaraokeDrillOut,
  KaraokeEvaluationOut,
  TrainingProgressOut,
)
from app.core.config import settings
from app.core.exceptions import ApiError
from app.modules.karaoke.service import get_catalog_preview, get_drill_by_id, get_karaoke_catalog

router = APIRouter(prefix="/karaoke", tags=["karaoke"])


@router.get("/catalog", response_model=KaraokeCatalogOut)
def fetch_karaoke_catalog(_: dict = Depends(get_current_user)) -> KaraokeCatalogOut:
  """Get full karaoke drill catalog. Requires authentication."""
  catalog = get_karaoke_catalog()
  return KaraokeCatalogOut.model_validate(catalog)


@router.get("/catalog/preview", response_model=KaraokeCatalogPreviewOut)
def fetch_karaoke_catalog_preview(_: dict = Depends(get_current_user_or_guest)) -> KaraokeCatalogPreviewOut:
  """Get lightweight catalog preview. Accessible by guests."""
  preview = get_catalog_preview()
  return KaraokeCatalogPreviewOut.model_validate(preview)


@router.get("/catalog/{drill_id}", response_model=KaraokeDrillOut)
def fetch_karaoke_drill(drill_id: str, _: dict = Depends(get_current_user)) -> KaraokeDrillOut:
  """Get single drill detail. Requires authentication."""
  drill = get_drill_by_id(drill_id)
  if drill is None:
    raise ApiError(
      code="DRILL_NOT_FOUND",
      message=f"Karaoke drill '{drill_id}' not found",
      status_code=404,
    )
  return KaraokeDrillOut.model_validate(drill)


@router.get("/progress", response_model=TrainingProgressOut)
def fetch_karaoke_progress(current_user: dict = Depends(get_current_user)) -> TrainingProgressOut:
  """Get karaoke progress for current user."""
  from app.modules.karaoke.service import get_karaoke_progress as get_progress

  return TrainingProgressOut.model_validate(get_progress(current_user["uid"]))


@router.post("/evaluate-tone", response_model=KaraokeEvaluationOut)
async def evaluate_karaoke_tone(
  audio: UploadFile = File(...),
  pitch_score: float = Form(..., ge=0, le=100),
  rhythm_delay_ms: float = Form(..., ge=-5000, le=5000),
  current_user: dict = Depends(get_current_user),
) -> KaraokeEvaluationOut:
  """Evaluate a bounded audio sample using local analysis."""
  _ = current_user
  allowed_content_types = {
    "audio/aac",
    "audio/flac",
    "audio/mpeg",
    "audio/mp4",
    "audio/ogg",
    "audio/wav",
    "audio/webm",
    "audio/x-wav",
  }
  content_type = (audio.content_type or "").lower().strip()
  if content_type not in allowed_content_types:
    raise ApiError(
      code="AUDIO_TYPE_UNSUPPORTED",
      message="Please upload a supported audio recording.",
      status_code=415,
    )

  audio_bytes = await audio.read(settings.audio_snippet_max_bytes + 1)
  if len(audio_bytes) > settings.audio_snippet_max_bytes:
    raise ApiError(
      code="AUDIO_TOO_LARGE",
      message="That recording is too large to analyze. Please record a shorter clip.",
      status_code=413,
    )
  if not audio_bytes:
    raise ApiError(
      code="AUDIO_EMPTY",
      message="The recording was empty. Please try again.",
      status_code=422,
    )

  from app.modules.karaoke.service import evaluate_tone_and_get_feedback

  result = evaluate_tone_and_get_feedback(audio_bytes, pitch_score, rhythm_delay_ms)
  return KaraokeEvaluationOut(**result)
