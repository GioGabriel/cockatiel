def test_ai_queue_failure_messages_are_safe_for_client_visible_state():
  from app.queue.consumers.ai_evaluation import _safe_failure_message

  message = _safe_failure_message(ValueError("provider response included secret-key"))

  assert message == "The coaching review returned an invalid response. Please try again."
  assert "secret-key" not in message


def test_ai_queue_timeout_has_a_recoverable_user_message():
  from app.queue.consumers.ai_evaluation import _safe_failure_message

  assert _safe_failure_message(TimeoutError("provider timed out")) == (
    "The coaching review timed out. Please try again."
  )


def test_legacy_ai_error_details_are_redacted_at_the_api_boundary():
  from app.core.safe_errors import public_ai_failure_message

  assert public_ai_failure_message("provider key=secret") == (
    "The coaching review could not be completed. Please try again."
  )
