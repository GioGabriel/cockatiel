from fastapi import APIRouter

from app.api.v1.endpoints.ai import router as ai_router
from app.api.v1.endpoints.analytics import router as analytics_router
from app.api.v1.endpoints.audio_snippets import router as audio_snippets_router
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.feedback import router as feedback_router
from app.api.v1.endpoints.metrics import router as metrics_router
from app.api.v1.endpoints.profile import router as profile_router
from app.api.v1.endpoints.sessions import router as sessions_router
from app.api.v1.endpoints.karaoke import router as karaoke_router
from app.api.v1.endpoints.training import router as training_router

api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(profile_router)
api_router.include_router(ai_router)
api_router.include_router(sessions_router)
api_router.include_router(metrics_router)
api_router.include_router(feedback_router)
api_router.include_router(analytics_router)
api_router.include_router(audio_snippets_router)
api_router.include_router(training_router)
api_router.include_router(karaoke_router)
