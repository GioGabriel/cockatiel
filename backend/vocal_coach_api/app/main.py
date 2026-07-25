import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from time import perf_counter
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.exceptions import ApiError, error_envelope
from app.observability.logging.setup import configure_logging
from app.observability.metrics.registry import increment, observe, snapshot
from app.workers.ai_evaluation_worker import AIEvaluationWorker
from app.workers.audio_snippet_cleanup_worker import AudioSnippetCleanupWorker

configure_logging()
logger = logging.getLogger("vocal-coach-api")

@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
  ai_worker: AIEvaluationWorker | None = None
  snippet_cleanup_worker: AudioSnippetCleanupWorker | None = None
  logger.info(
    "runtime_config env=%s auth_bypass=%s firestore_enabled=%s openrouter_enabled=%s openrouter_model=%s prompt_version=%s ai_async_enabled=%s ai_worker_enabled=%s audio_snippet_storage_backend=%s audio_snippet_retention_days=%s audio_snippet_cleanup_worker_enabled=%s audio_snippet_cleanup_interval_sec=%s",
    settings.app_env,
    settings.auth_bypass,
    settings.firestore_enabled,
    settings.openrouter_enabled,
    settings.openrouter_model,
    settings.prompt_version,
    settings.ai_async_enabled,
    settings.ai_worker_enabled,
    settings.audio_snippet_storage_backend,
    settings.audio_snippet_retention_days,
    settings.audio_snippet_cleanup_worker_enabled,
    settings.audio_snippet_cleanup_interval_sec,
  )
  if settings.ai_async_enabled and settings.ai_worker_enabled:
    ai_worker = AIEvaluationWorker()
    ai_worker.start()
  if settings.audio_snippet_cleanup_worker_enabled:
    snippet_cleanup_worker = AudioSnippetCleanupWorker(interval_seconds=settings.audio_snippet_cleanup_interval_sec)
    snippet_cleanup_worker.start()

  try:
    yield
  finally:
    if ai_worker:
      ai_worker.stop()
    if snippet_cleanup_worker:
      snippet_cleanup_worker.stop()


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.api_prefix)


@app.middleware("http")
async def request_context_middleware(request: Request, call_next):
  trace_id = request.headers.get("x-request-id", str(uuid4()))
  request.state.trace_id = trace_id
  start = perf_counter()
  try:
    response = await call_next(request)
    duration_ms = (perf_counter() - start) * 1000
    response.headers["x-request-id"] = trace_id
    observe("api_latency_ms", duration_ms)
    increment("api_requests_total")
    logger.info(
      "request_complete trace_id=%s method=%s path=%s status=%s duration_ms=%.2f",
      trace_id,
      request.method,
      request.url.path,
      response.status_code,
      duration_ms,
    )
    return response
  except Exception:
    increment("api_requests_failed_total")
    raise


@app.exception_handler(ApiError)
async def api_error_handler(request: Request, exc: ApiError):
  trace_id = getattr(request.state, "trace_id", str(uuid4()))
  return JSONResponse(
    status_code=exc.status_code,
    content=error_envelope(exc.code, exc.message, trace_id, exc.details),
  )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
  trace_id = getattr(request.state, "trace_id", str(uuid4()))
  return JSONResponse(
    status_code=422,
    content=error_envelope("VALIDATION_ERROR", "Request validation failed.", trace_id, {"errors": exc.errors()}),
  )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, _: Exception):
  trace_id = getattr(request.state, "trace_id", str(uuid4()))
  return JSONResponse(
    status_code=500,
    content=error_envelope("INTERNAL_ERROR", "Unexpected server error.", trace_id),
  )


@app.get("/health")
def health() -> dict[str, str]:
  return {"status": "ok", "env": settings.app_env}


@app.get("/metrics")
def metrics() -> dict[str, object]:
  return snapshot()
