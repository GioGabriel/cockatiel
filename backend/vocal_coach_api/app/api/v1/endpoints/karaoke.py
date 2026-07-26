from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user, get_current_user_or_guest
from app.api.v1.schemas import KaraokeCatalogOut, KaraokeCatalogPreviewOut, KaraokeDrillOut, TrainingProgressOut
from app.core.exceptions import ApiError
from app.modules.karaoke.service import get_karaoke_catalog, get_drill_by_id, get_catalog_preview

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

from fastapi import UploadFile, File, Form
from pydantic import BaseModel

class KaraokeEvaluationOut(BaseModel):
    pitch_score: float
    rhythm_delay_ms: float
    tone_score: float
    ai_feedback: str

@router.post("/evaluate-tone", response_model=KaraokeEvaluationOut)
async def evaluate_karaoke_tone(
    audio: UploadFile = File(...),
    pitch_score: float = Form(...),
    rhythm_delay_ms: float = Form(...),
    current_user: dict = Depends(get_current_user)
) -> KaraokeEvaluationOut:
    """Evaluate tone using librosa and generate AI feedback."""
    from app.modules.karaoke.service import evaluate_tone_and_get_feedback
    
    # Read the uploaded file into bytes
    audio_bytes = await audio.read()
    
    # Evaluate tone and generate feedback
    result = evaluate_tone_and_get_feedback(
        audio_bytes, 
        pitch_score, 
        rhythm_delay_ms
    )
    
    return KaraokeEvaluationOut(**result)
