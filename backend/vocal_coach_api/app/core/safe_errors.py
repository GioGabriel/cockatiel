_SAFE_AI_FAILURE_MESSAGES = {
  "The coaching review timed out. Please try again.",
  "The coaching review returned an invalid response. Please try again.",
  "The coaching review service was unavailable. Please try again.",
  "The coaching review could not be completed. Please try again.",
}


def public_ai_failure_message(value: object) -> str:
  """Prevent legacy or provider-specific error details from reaching clients."""
  message = value.strip() if isinstance(value, str) else ""
  return message if message in _SAFE_AI_FAILURE_MESSAGES else "The coaching review could not be completed. Please try again."
