# Observability

Core metrics:
- API: `api_requests_total`, `api_requests_failed_total`, `api_latency_ms`
- AI global: `ai_feedback_requests_total`, `ai_feedback_success_total`, `ai_feedback_failure_total`, `ai_feedback_fallback_total`, `ai_feedback_latency_ms`
- AI per prompt version: `ai_feedback_success_prompt_<version>_total`, `ai_feedback_failure_prompt_<version>_total`, `ai_feedback_fallback_prompt_<version>_total`
- AI per model: `ai_model_usage_<model>`
- AI failure reasons: `ai_feedback_model_failure_reason_<reason>_total`, `ai_feedback_fallback_reason_<reason>_total`

Guidelines:
- Include `trace_id` in every request log and error envelope.
- Persist `model_used`, `prompt_version`, and `latency_ms` for each feedback response.
- Use prompt-version counters to compare `v1a` vs `v1b` outcomes during A/B tests.
