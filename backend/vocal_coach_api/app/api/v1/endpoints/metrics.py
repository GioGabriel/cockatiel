from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import MetricBatchIn, MetricsAcceptedOut
from app.modules.sessions.service import append_metrics

router = APIRouter(prefix="/sessions", tags=["metrics"])


@router.post("/{session_id}/metrics", response_model=MetricsAcceptedOut, status_code=202)
def submit_metrics(
  session_id: str,
  payload: MetricBatchIn,
  current_user: dict = Depends(get_current_user),
) -> MetricsAcceptedOut:
  accepted = append_metrics(session_id=session_id, user_id=current_user["uid"], metrics=payload.metrics)
  return MetricsAcceptedOut(session_id=session_id, accepted_count=accepted, status="accepted")
