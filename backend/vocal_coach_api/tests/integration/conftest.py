import os
import shutil
from collections.abc import Iterator
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient


def _as_bool(name: str, default: bool) -> bool:
  raw = os.getenv(name, str(default)).strip().lower()
  return raw in {"1", "true", "yes", "on"}


def _as_models(name: str, default: str) -> tuple[str, ...]:
  raw = os.getenv(name, default)
  models = tuple(item.strip() for item in raw.split(",") if item.strip())
  return models or tuple(item.strip() for item in default.split(",") if item.strip())


_TEST_USE_OLLAMA = _as_bool("TEST_USE_OLLAMA", False)
_TEST_MOCK_OLLAMA = _as_bool("TEST_MOCK_OLLAMA", True)
_TEST_OLLAMA_MODELS = _as_models("TEST_OLLAMA_MODELS", "llama3:latest,qwen2.5:7b")
_TEST_PROMPT_VERSION = os.getenv("TEST_PROMPT_VERSION", "v1")

os.environ["AUTH_BYPASS"] = "true"
os.environ["FIRESTORE_ENABLED"] = "false"
os.environ["OLLAMA_ENABLED"] = "true" if _TEST_USE_OLLAMA else "false"
os.environ["OLLAMA_MODELS"] = ",".join(_TEST_OLLAMA_MODELS)
os.environ["PROMPT_VERSION"] = _TEST_PROMPT_VERSION
os.environ["AUDIO_SNIPPET_STORAGE_BACKEND"] = "local"
os.environ["AUDIO_SNIPPET_LOCAL_DIR"] = "/tmp/vocal-coach-audio-snippets-tests"
os.environ["AUDIO_SNIPPET_RETENTION_DAYS"] = "30"

from app.main import app
from app.observability.metrics.registry import reset as reset_metrics
from app.queue.tasks.ai_evaluation_queue import clear as clear_ai_queue
from app.repositories.provider import reset_repository_bundle
from app.storage.audio_snippets.service import reset_audio_snippet_storage


@pytest.fixture(autouse=True)
def _reset_runtime_state() -> Iterator[None]:
  reset_repository_bundle()
  reset_audio_snippet_storage()
  reset_metrics()
  clear_ai_queue()
  shutil.rmtree(os.environ["AUDIO_SNIPPET_LOCAL_DIR"], ignore_errors=True)
  yield
  reset_repository_bundle()
  reset_audio_snippet_storage()
  reset_metrics()
  clear_ai_queue()
  shutil.rmtree(os.environ["AUDIO_SNIPPET_LOCAL_DIR"], ignore_errors=True)


@pytest.fixture(autouse=True)
def _configure_ai_mode(monkeypatch) -> Iterator[None]:
  if not _TEST_USE_OLLAMA:
    yield
    return

  from app.ai_engine.orchestrator import service as orchestrator

  monkeypatch.setattr(
    orchestrator,
    "settings",
    SimpleNamespace(
      prompt_version=_TEST_PROMPT_VERSION,
      ollama_enabled=True,
      ollama_base_url="http://localhost:11434",
      ollama_model=_TEST_OLLAMA_MODELS[0],
      ollama_models=_TEST_OLLAMA_MODELS,
      ollama_timeout_s=10,
      ollama_temperature=0.2,
    ),
  )

  if _TEST_MOCK_OLLAMA:
    class FakeOllamaClient:
      def __init__(self, *, model: str, **kwargs):
        self.model = model

      def generate_json(self, *, system_prompt: str, user_prompt: str) -> tuple[dict[str, list[str]], int]:
        return {
          "strengths": ["Accurate pitch center on held notes"],
          "improvements": ["Improve phrase ending breath support"],
          "next_exercises": ["Sustain-release breath drill"],
        }, 12

    monkeypatch.setattr(orchestrator, "OllamaClient", FakeOllamaClient)

  yield


@pytest.fixture
def client() -> Iterator[TestClient]:
  with TestClient(app) as test_client:
    yield test_client


@pytest.fixture
def auth_headers() -> dict[str, str]:
  return {"Authorization": "Bearer dev_test-user"}


@pytest.fixture(scope="session")
def use_ollama_mode() -> bool:
  return _TEST_USE_OLLAMA


@pytest.fixture(scope="session")
def expected_feedback_models() -> set[str]:
  if not _TEST_USE_OLLAMA:
    return {"fallback-rules"}
  if _TEST_MOCK_OLLAMA:
    return {_TEST_OLLAMA_MODELS[0]}
  return set(_TEST_OLLAMA_MODELS) | {"fallback-rules"}
