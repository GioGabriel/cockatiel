# Contributing to Cockatiel

Cockatiel uses a contracts-first, modular architecture. Small, reviewable
changes are preferred over broad rewrites that are difficult to validate.

## Change workflow

1. Read the relevant architecture and product documents.
2. Inspect `git status` and the current diff; preserve useful uncommitted work.
3. For cross-layer or persisted behavior, update `contracts/` first and search all callers.
4. Add or update failure-path and behavior tests before implementation.
5. Implement the smallest cohesive change in the owning module.
6. Run formatting, static analysis, focused tests, the full relevant suite, and a production build when available.
7. Review the diff for accidental secrets, raw exceptions, debug output, accessibility regressions, and unrelated cleanup.

## Coding style

### Python

- Use Python 3.11+ typing and the project Ruff configuration.
- Keep endpoint code thin; business rules belong in services and persistence belongs in repositories.
- Parse configuration only in `app/core/config.py`.
- Raise `ApiError` for expected failures and return the standard error envelope with a trace ID.
- Never expose raw exception strings, tokens, provider responses, credentials, or connection strings to clients or logs.
- Bound provider calls, retries, request sizes, and worker loops. Make retries idempotent where possible.

### Dart/Flutter

- Run `dart format` and `flutter analyze` on changed code.
- Keep network calls in `core/network`, cross-feature DTOs in `shared/models`, and presentation code free of direct persistence concerns.
- Use `Theme.of(context)` and the shared theme tokens instead of feature-specific colors or text styles.
- Preserve loading, error, empty, retry, permission, focus, semantics, and text-scaling behavior.
- Dispose audio players, microphone streams, timers, controllers, and subscriptions on every exit path.

### Contracts and tests

- Use strict request models for public input and version changes that affect persisted data.
- Tests should assert behavior and user-visible contracts, not private implementation details.
- Prefer deterministic fakes for Firebase, Firestore, Google AI Studio, LRCLIB, and audio providers.
- Coverage is reported by risk area; a global 100% threshold is not a substitute for authorization, isolation, fallback, and lifecycle tests.

## Design rules

Cockatiel keeps its bird, microphone, waveform, and dark premium identity while
using matte layered surfaces, clear hierarchy, restrained accents, and strong
contrast. Decorative gradients, uncontrolled neon, heavy blur, and unexplained
glow are not default product patterns. See
[`docs/product/design-system.md`](docs/product/design-system.md).

## Security and external systems

Do not deploy, push, migrate production data, rotate credentials, or modify
Firebase/Firestore/Render state as part of a code-only change. External state is
unverified unless explicitly inspected. Use protected secret injection and keep
production authentication fail-closed.
