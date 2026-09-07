from app.repositories.memory.sessions_repository import InMemorySessionRepository


def test_memory_session_update_returns_the_written_fields_contract() -> None:
  repository = InMemorySessionRepository()
  repository.create(
    {
      "session_id": "session-1",
      "user_id": "user-1",
      "status": "started",
    }
  )

  assert repository.update("session-1", {"status": "processing"}) == {
    "status": "processing",
  }
