# Engineering Best Practices

Cross-cutting patterns for reliability, security, and maintainability in the Vocal Coach platform.

## Security

### Authentication

- Firebase Auth tokens validated on every request (unless `AUTH_BYPASS=true` in dev).
- Never trust client-supplied `user_id`. Extract from the auth token server-side.
- Use short-lived tokens. Mobile refreshes automatically via Firebase SDK.

### Data Validation

- Validate at the API boundary (Pydantic models with constraints).
- Reject unexpected fields with `extra="forbid"` on input models.
- Sanitize any user-supplied string that will appear in logs or prompts.
- Never interpolate user input into system prompts — use template placeholders.

### Secrets Management

- All secrets in env vars, never in code or committed files.
- `.env` files are gitignored. Use `.env.example` for documentation.
- Service account JSON files are gitignored.

## Error Handling

### Backend

- Use domain-specific error codes (`SESSION_NOT_FOUND`, `MAX_ATTEMPTS_REACHED`).
- Attach `trace_id` to every error response for debugging.
- Log errors with context (session_id, user_id, operation) but never log secrets or full request bodies.
- Background workers catch all exceptions, log, and continue (never crash the worker loop).

### Mobile

- Network errors → retry prompt or graceful degradation (show cached data).
- Auth errors (401) → redirect to login.
- Validation errors (422) → show field-level feedback.
- Unknown errors → generic "Something went wrong" with retry option.
- Never show stack traces or raw JSON to users.

## Observability

### Metrics (Backend)

- Use the custom `increment()` / `observe()` / `snapshot()` registry.
- Name metrics with underscore-separated segments: `ai_feedback_success_total`.
- Observe latency for all external calls (Ollama, Firestore, storage).
- Count successes, failures, and fallbacks separately.

### Logging

- Use structured key-value logging: `logger.info("event_name key1=%s key2=%s", val1, val2)`.
- Log at appropriate levels: INFO for flow milestones, WARNING for fallbacks, ERROR for unexpected failures.
- Include `session_id` and `trace_id` in all log lines for correlation.

### Mobile Telemetry

- Track key user flows (session_started, session_completed, feedback_viewed).
- Don't track PII or audio content in telemetry.
- Use `core/telemetry/` for centralized event dispatch.

## Testing Strategy

### Backend Test Pyramid

- Unit tests: service logic, scoring functions, prompt resolution, schema validation.
- Integration tests: full endpoint flows via test client.
- Contract tests: ensure responses match OpenAPI spec.
- Load tests: script-based (in `tests/load/`), not automated in CI yet.

### Mobile Testing

- Widget tests for complex UI components.
- Unit tests for business logic in `domain/`.
- `dart analyze` must pass with zero issues.
- `flutter build apk --debug` must succeed.

### Test Data

- Use seed scripts (`scripts/seed_sessions.py`) for populating test data.
- Tests use in-memory repositories (never hit real Firestore in unit/integration tests).
- Each test is isolated — no shared state between test functions.

## Git & Branching

- Feature branches off `main`.
- Branch naming: `feature/<short-description>`, `fix/<issue-description>`.
- Commit messages: imperative mood, under 72 chars. Body for context.
- Squash-merge to main for clean history.
- Never commit `.env`, credentials, or generated files.

## Sprint Workflow

- `Sprint.md` is the single source of truth for planning and status.
- Update sprint status immediately after significant progress.
- Include validation evidence (test output) in each sprint section.
- Keep implementation checklists file-oriented (list exact files to create/modify).

## Dependency Management

### Backend (Python)

- Pin major versions in `pyproject.toml` (e.g., `fastapi>=0.115.0`).
- Use optional dependency groups (`dev`, `firestore`) for environment-specific deps.
- Run `pip install -e ".[dev]"` for local development.

### Mobile (Flutter)

- Pin to caret versions in `pubspec.yaml` (e.g., `^6.1.3`).
- Run `flutter pub get` after any pubspec change.
- Prefer well-maintained Flutter-community packages.
- Audit new dependencies for maintenance status and license compatibility.
