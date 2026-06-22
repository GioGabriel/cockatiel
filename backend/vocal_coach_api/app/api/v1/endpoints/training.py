from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import TrainingCatalogOut, TrainingProgressOut, TrainingRecommendationsOut
from app.modules.training.service import get_training_catalog, get_training_progress, get_training_recommendations

router = APIRouter(prefix="/training", tags=["training"])


@router.get("/catalog", response_model=TrainingCatalogOut)
def fetch_training_catalog(_: dict = Depends(get_current_user)) -> TrainingCatalogOut:
  return TrainingCatalogOut.model_validate(get_training_catalog())


@router.get("/progress", response_model=TrainingProgressOut)
def fetch_training_progress(current_user: dict = Depends(get_current_user)) -> TrainingProgressOut:
  return TrainingProgressOut.model_validate(get_training_progress(current_user["uid"]))


@router.get("/recommendations", response_model=TrainingRecommendationsOut)
def fetch_training_recommendations(current_user: dict = Depends(get_current_user)) -> TrainingRecommendationsOut:
  return TrainingRecommendationsOut.model_validate(get_training_recommendations(current_user["uid"]))
