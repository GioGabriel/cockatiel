from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import CoachingFeedback
from app.core.exceptions import ApiError
from app.modules.sessions.service import get_session

router = APIRouter(prefix="/sessions", tags=["feedback"])


@router.get("/{session_id}/feedback", response_model=CoachingFeedback)
def get_feedback(session_id: str, current_user: dict = Depends(get_current_user)) -> CoachingFeedback:
  session = get_session(session_id=session_id, user_id=current_user["uid"])
  feedback = session.get("feedback")
  if feedback is None:
    if session.get("status") == "failed":
      raise ApiError(
        code="FEEDBACK_FAILED",
        message="AI feedback generation failed.",
        status_code=409,
        details={"reason": session.get("failure_reason", "unknown")},
      )
    raise ApiError(code="FEEDBACK_NOT_READY", message="Feedback is not available yet.", status_code=404)
  return feedback
