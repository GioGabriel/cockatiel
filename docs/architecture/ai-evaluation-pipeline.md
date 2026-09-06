# AI Evaluation Pipeline

Pipeline stages:
1. Session metrics are aggregated into a canonical summary.
2. Prompt registry resolves template version (`PROMPT_VERSION`) and renders system/user prompts.
   - `PROMPT_VERSION=ab` enables deterministic A/B prompt routing between `v1a` and `v1b` per session.
3. The deterministic Coaching Logic Engine evaluates metrics and remains authoritative.
4. If configured, Google AI Studio is used only for bounded natural-language coaching detail.
5. The backend tries configured Gemini models/keys until a valid structured payload is produced.
6. Google AI Studio receives the deterministic score breakdown, recording
   evidence, metric statuses/reasons, target segments, evidence quality, sample
   count, strengths, and improvements so it can explain the result in plain
   language. It is asked for `application/json` with a schema containing a
   bounded `summary` and up to three structured `detailed_improvements`.
   Pydantic validates every field and metric key before the payload can replace
   the deterministic narrative. It never receives raw audio and cannot change
   the numeric score.
7. On any provider failure or malformed output, the orchestrator applies deterministic fallback feedback.
8. Response metadata is persisted with `model_used`, `prompt_version`, and `latency_ms`.

Runtime configuration:
- `GOOGLE_API_KEYS` is a comma-separated list of protected Google AI Studio
  keys. The singular `GOOGLE_API_KEY` is supported for local development.
- `GOOGLE_AI_MODEL` defaults to the stable `gemini-2.5-flash-lite` model.
- `GOOGLE_AI_FALLBACK_MODELS` optionally supplies a comma-separated fallback
  model list; the default fallback is `gemini-2.5-flash`.
- `GOOGLE_AI_ENABLED`, timeout, total deadline, temperature, and output-token
  bounds are configured server-side. No key is sent to the Flutter client.

Google documents structured output for the legacy `generateContent` API in its
[Gemini API guide](https://ai.google.dev/gemini-api/docs/generate-content/structured-output?hl=en)
and documents that quota is applied per Google Cloud project in its
[rate-limit guide](https://ai.google.dev/gemini-api/docs/rate-limits?hl=en).

Observability counters:
- `ai_feedback_requests_total`
- `ai_feedback_success_total`
- `ai_feedback_success_prompt_<version>_total`
- `google_ai_feedback_succeeded` structured log with model, prompt version,
  latency, and improvement count
- `ai_feedback_model_failure_total`
- `ai_feedback_model_failure_reason_timeout_total`
- `ai_feedback_model_failure_reason_http_error_total`
- `ai_feedback_model_failure_reason_connection_error_total`
- `ai_feedback_validation_failure_total`
- `ai_feedback_fallback_total`
- `ai_feedback_fallback_prompt_<version>_total`
- `ai_feedback_fallback_reason_google_ai_disabled_total`
- `ai_feedback_fallback_reason_google_ai_unavailable_total`
- `ai_model_usage_google_ai_<model>`
