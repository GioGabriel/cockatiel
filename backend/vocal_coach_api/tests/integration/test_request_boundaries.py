"""Malformed inputs must fail validation without leaking payloads or mutating data."""
import re

import pytest
from pydantic import ValidationError

from app.api.v1.schemas import MetricSegmentEvidence, VoiceMetricEvidence
from app.main import app

JSON_OPERATIONS = [
  (method.upper(), path)
  for path, operations in app.openapi()["paths"].items()
  for method, operation in operations.items()
  if method in {"post", "put", "patch"}
  and "application/json" in operation.get("requestBody", {}).get("content", {})
]


@pytest.mark.parametrize("method,path", JSON_OPERATIONS)
@pytest.mark.parametrize("body", ["{", "null", "[]", '"private-input-marker"', "42"])
def test_json_operations_reject_malformed_or_wrong_shape_bodies(client, auth_headers, method, path, body):
  response = client.request(
    method, re.sub(r"\{[^}]+\}", "unknown-resource", path),
    headers={**auth_headers, "Content-Type": "application/json"}, content=body,
  )
  assert response.status_code == 422, (method, path, response.text)
  assert response.json()["error"]["code"] == "VALIDATION_ERROR"
  assert "private-input-marker" not in response.text
  assert response.headers["x-request-id"]


@pytest.mark.parametrize("number", [float("nan"), float("inf"), float("-inf")])
@pytest.mark.parametrize("model,field,required", [
  (MetricSegmentEvidence, "target_frequency_hz", {"segment_id": "target"}),
  (VoiceMetricEvidence, "mean_onset_delay_ms", {}),
  (VoiceMetricEvidence, "p95_onset_delay_ms", {}),
  (VoiceMetricEvidence, "mean_settling_time_ms", {}),
])
def test_audio_evidence_rejects_nonfinite_measurements(model, field, required, number):
  with pytest.raises(ValidationError):
    model.model_validate({**required, field: number})


def test_voice_evidence_accepts_realistic_finite_measurements():
  evidence = VoiceMetricEvidence(
    mean_onset_delay_ms=123.5, p95_onset_delay_ms=400, mean_settling_time_ms=250,
    segments=[MetricSegmentEvidence(segment_id="target", target_frequency_hz=440)],
  )
  assert evidence.segments[0].target_frequency_hz == 440
