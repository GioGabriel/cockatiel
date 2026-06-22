# Token Optimization & AI Engine Best Practices

Guidelines for efficient LLM token usage in the Vocal Coach AI feedback pipeline and agent interactions.

## AI Feedback Pipeline (Backend)

### Prompt Design Principles

- Keep system prompts under 400 tokens. Be directive, not conversational.
- User prompts should contain only structured data (JSON or key-value), not prose.
- Use bullet points and abbreviated labels in prompts, not full sentences.
- Never send raw metric arrays to the LLM. Always pre-summarize into aggregates (avg, min, max, count).
- Include only the fields the LLM needs to reason about; strip internal IDs, timestamps, and metadata.

### Structured Output

- Always request JSON output from the model (via `generate_json`).
- Validate responses with `LlmFeedbackPayload` Pydantic model before processing.
- Define the exact output schema in the system prompt so the model doesn't guess field names.
- Keep response fields to: `strengths` (max 3), `improvements` (max 3), `next_exercises` (max 2).

### Model Routing & Fallback

- Use the smallest model that achieves acceptable quality for the task.
- Route cascade: try models in configured order, fallback to deterministic rules on total failure.
- Set `temperature: 0.2` for consistency. Feedback should be reproducible, not creative.
- Timeout aggressively (`OLLAMA_TIMEOUT_S`); better to fallback fast than wait for a slow model.

### Context Window Management

- Never send full session history. Send only the latest attempt's metric summary.
- For training sessions with multiple attempts, send only the best attempt + improvement delta.
- Cap prompt context to: exercise name, difficulty, metric summary (6-8 fields), and score.
- If adding diction/transcription context, include only: reference phrase, transcript, and diff (not raw audio bytes or alignment arrays).

## Agent Interaction Optimization (Kiro)

### File Reading Strategy

- Read only what's needed. Don't read entire directories to understand one function.
- Use the project architecture steering to know where things live before exploring.
- For backend changes: check `schemas.py` + the relevant `modules/<name>/service.py` + endpoint file.
- For mobile changes: check `shared/models/` + the relevant `features/<name>/presentation/` + `api_client.dart`.

### Change Efficiency

- Prefer targeted `str_replace` over full file rewrites.
- When adding a new endpoint: update router, add endpoint file, add schemas, update service. In that order.
- When adding a mobile feature: add model DTO, add API client method, create feature page, wire routing.

### Batch Operations

- Group related file changes (e.g., schema + endpoint + service) in a single turn.
- Run validation once at the end of a batch, not after every file.
- For backend: `python3 -m pytest tests/unit tests/integration -q`.
- For mobile: `dart analyze` then `flutter build apk --debug`.

## Memory & Performance Patterns

### Backend Performance

- Repository queries should return only needed fields (project, not full documents).
- Use pagination for list endpoints; never return unbounded collections.
- Cache daily rollups for analytics (don't recompute from raw sessions on every request).
- Background workers should batch-process items, not spin per-item.
- Use `perf_counter()` for timing, not `time()`.

### Mobile Performance

- Cache API responses in memory for the session lifetime (don't re-fetch on every page visit).
- Use `const` widgets to avoid unnecessary rebuilds.
- Limit polling frequency (AI jobs poll every 3 seconds is the ceiling, not the floor).
- Dispose all timers, streams, and subscriptions to prevent memory leaks.
- Use `ListView.builder` with `itemCount` for all scrollable lists.
- Load images lazily; use `fadeInDuration` for network images.
- Minimize widget tree depth; flatten unnecessary nesting.
