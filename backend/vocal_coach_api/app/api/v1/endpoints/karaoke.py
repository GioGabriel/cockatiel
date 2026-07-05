from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user, get_current_user_or_guest
from app.api.v1.schemas import KaraokeCatalogOut, KaraokeCatalogPreviewOut, KaraokeDrillOut
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
