from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class LlmDetailedImprovement(BaseModel):
  model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

  metric_key: str = Field(min_length=1, max_length=80)
  priority: Literal["high", "medium", "low"] = "medium"
  finding: str = Field(min_length=1, max_length=280)
  evidence: str = Field(min_length=1, max_length=320)
  why_it_matters: str = Field(min_length=1, max_length=320)
  action: str = Field(min_length=1, max_length=320)
  practice_plan: str = Field(min_length=1, max_length=320)


class LlmFeedbackPayload(BaseModel):
  model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

  summary: str = Field(min_length=1)
  detailed_improvements: list[LlmDetailedImprovement] = Field(min_length=1, max_length=3)
