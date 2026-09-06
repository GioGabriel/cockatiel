import os
import shutil
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient


def _as_bool(name: str, default: bool) -> bool:
  raw = os.getenv(name, str(default)).strip().lower()
  return raw in {"1", "true", "yes", "on"}


_TEST_PROMPT_VERSION = os.getenv("TEST_PROMPT_VERSION", "v1")

os.environ["AUTH_BYPASS"] = "true"
os.environ["FIRESTORE_ENABLED"] = "false"
os.environ["GOOGLE_AI_ENABLED"] = "false"
os.environ["GOOGLE_API_KEYS"] = ""
os.environ["PROMPT_VERSION"] = _TEST_PROMPT_VERSION
os.environ["AUDIO_SNIPPET_STORAGE_BACKEND"] = "local"
os.environ["AUDIO_SNIPPET_LOCAL_DIR"] = "/tmp/vocal-coach-audio-snippets-tests"
os.environ["AUDIO_SNIPPET_RETENTION_DAYS"] = "30"

from app.main import app  # noqa: E402  # environment must be set before app import
from app.observability.metrics.registry import reset as reset_metrics  # noqa: E402
from app.queue.tasks.ai_evaluation_queue import clear as clear_ai_queue  # noqa: E402
from app.repositories.provider import reset_repository_bundle  # noqa: E402
from app.storage.audio_snippets.service import reset_audio_snippet_storage  # noqa: E402


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


@pytest.fixture
def client() -> Iterator[TestClient]:
  with TestClient(app) as test_client:
    yield test_client


@pytest.fixture
def auth_headers() -> dict[str, str]:
  return {"Authorization": "Bearer dev_test-user"}


@pytest.fixture(scope="session")
def expected_feedback_models() -> set[str]:
  return {"coaching-logic-engine"}
