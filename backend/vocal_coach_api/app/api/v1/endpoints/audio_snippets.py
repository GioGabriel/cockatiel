from fastapi import APIRouter, Depends, Query

from app.api.v1.dependencies import get_current_user
from app.api.v1.schemas import AudioSnippetCleanupOut, AudioSnippetCreateIn, AudioSnippetListOut, AudioSnippetOut
from app.modules.audio_snippets.service import cleanup_expired_audio_snippets, create_audio_snippet, list_session_audio_snippets

router = APIRouter(tags=["audio-snippets"])


@router.post("/sessions/{session_id}/audio-snippets", response_model=AudioSnippetOut, status_code=201)
def upload_audio_snippet(
  session_id: str,
  payload: AudioSnippetCreateIn,
  current_user: dict = Depends(get_current_user),
) -> AudioSnippetOut:
  snippet = create_audio_snippet(user_id=current_user["uid"], session_id=session_id, payload=payload)
  return AudioSnippetOut.model_validate(snippet)


@router.get("/sessions/{session_id}/audio-snippets", response_model=AudioSnippetListOut)
def list_audio_snippets(session_id: str, current_user: dict = Depends(get_current_user)) -> AudioSnippetListOut:
  snippets = list_session_audio_snippets(user_id=current_user["uid"], session_id=session_id)
  return AudioSnippetListOut(session_id=session_id, snippets=[AudioSnippetOut.model_validate(item) for item in snippets])


@router.post("/audio-snippets/cleanup", response_model=AudioSnippetCleanupOut)
def cleanup_audio_snippets(
  current_user: dict = Depends(get_current_user),
  before_ms: int | None = Query(default=None, ge=0),
) -> AudioSnippetCleanupOut:
  result = cleanup_expired_audio_snippets(user_id=current_user["uid"], before_ms=before_ms)
  return AudioSnippetCleanupOut.model_validate(result)
