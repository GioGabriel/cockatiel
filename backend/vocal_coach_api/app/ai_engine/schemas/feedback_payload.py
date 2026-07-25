from pydantic import BaseModel, ConfigDict, Field, field_validator


class LlmFeedbackPayload(BaseModel):
  model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

  summary: str = Field(min_length=1)
