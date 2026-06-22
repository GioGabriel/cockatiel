# AI Evaluation Pipeline

Pipeline stages:
1. Session metrics are aggregated into a canonical summary.
2. Prompt registry resolves template version (`PROMPT_VERSION`) and renders system/user prompts.
   - `PROMPT_VERSION=ab` enables deterministic A/B prompt routing between `v1a` and `v1b` per session.
3. Model router resolves ordered Ollama candidates (`OLLAMA_MODELS`).
4. Backend tries models in order until a valid structured payload is produced.
5. AI payload is validated against strict schema (`strengths`, `improvements`, `next_exercises` all required and non-empty).
6. On any model failure or malformed output, orchestrator applies deterministic fallback feedback.
7. Response metadata is persisted with `model_used`, `prompt_version`, and `latency_ms`.

Observability counters:
- `ai_feedback_requests_total`
- `ai_feedback_success_total`
- `ai_feedback_success_prompt_<version>_total`
- `ai_feedback_model_failure_total`
- `ai_feedback_model_failure_reason_timeout_total`
- `ai_feedback_model_failure_reason_http_error_total`
- `ai_feedback_model_failure_reason_connection_error_total`
- `ai_feedback_validation_failure_total`
- `ai_feedback_failure_total`
- `ai_feedback_failure_prompt_<version>_total`
- `ai_feedback_fallback_total`
- `ai_feedback_fallback_prompt_<version>_total`
- `ai_feedback_fallback_reason_ollama_disabled_total`
- `ai_feedback_fallback_reason_all_models_failed_total`
- `ai_model_usage_<model>`
