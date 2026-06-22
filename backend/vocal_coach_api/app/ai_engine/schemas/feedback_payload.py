from pydantic import BaseModel, ConfigDict, Field, field_validator


class LlmFeedbackPayload(BaseModel):
  model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

  strengths: list[str] = Field(min_length=1)
  improvements: list[str] = Field(min_length=1)
  next_exercises: list[str] = Field(min_length=1)

  @field_validator("strengths", "improvements", "next_exercises")
  @classmethod
  def validate_items(cls, values: list[str]) -> list[str]:
    sanitized = [item.strip() for item in values if item and item.strip()]
    if not sanitized:
      raise ValueError("Feedback lists must contain at least one non-empty item.")
    return sanitized
