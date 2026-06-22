from typing import Literal

from fastapi import APIRouter, Depends, Query

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import AnalyticsDashboardOut, AnalyticsTrendsOut
from app.modules.analytics.service import build_trends, get_or_build_dashboard

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/dashboard", response_model=AnalyticsDashboardOut)
def analytics_dashboard(current_user: dict = Depends(get_current_user)) -> AnalyticsDashboardOut:
  dashboard = get_or_build_dashboard(current_user["uid"])
  return AnalyticsDashboardOut.model_validate(dashboard)


@router.get("/trends", response_model=AnalyticsTrendsOut)
def analytics_trends(
  current_user: dict = Depends(get_current_user),
  range_key: Literal["7d", "30d", "90d"] = Query(default="30d", alias="range"),
) -> AnalyticsTrendsOut:
  trends = build_trends(current_user["uid"], range_key)
  return AnalyticsTrendsOut.model_validate(trends)
