# Cockatiel Enhanced — Project Architecture Guide

This is the canonical reference for the Vocal Coach monorepo architecture. All code must follow these structural conventions.

## Thesis Module ↔ Codebase Mapping

| Thesis Module | Backend | Mobile |
|---------------|---------|--------|
| Account Module | `api/v1/endpoints/auth.py`, Firebase Auth validation | `features/authentication/`, `core/auth/`, `core/state/app_state.dart` |
| Dashboard Module | `api/v1/endpoints/analytics.py`, `modules/analytics/` | `features/analytics_dashboard/`, `features/home_dashboard/` |
| Voice Room (Real-time AI) | `ai_engine/orchestrator/`, `modules/sessions/`, metrics ingest | `features/vocal_training/presentation/training_session_page.dart`, `core/audio/` |
| Coaching/Tutorial Module | `modules/training/catalog.py`, exercise specs, runtime plans | `features/vocal_training/` (briefing, catalog, guided steps) |
| Karaoke Module | Session mode `"karaoke"`, finalize + feedback flow | `features/karaoke_practice/` |
| Progress Tracking | `api/v1/endpoints/training.py` (progress, recommendations) | Analytics dashboard + training progress widgets |

"Voice Enhancement" = coaching-driven improvement via AI feedback, NOT audio signal transformation.
Target platform: Android only. No iOS or web builds required.

## Monorepo Layout

```
backend/vocal_coach_api/     → FastAPI backend (Python 3.11+)
mobile/vocal_coach_app/      → Flutter mobile app (Dart >=3.3.0)
contracts/                   → API contracts (OpenAPI), shared schemas
docs/architecture/           → Architecture docs
infra/                       → Deployment (Docker, Terraform)
.script/                     → One-command dev launcher
```

## Backend Architecture (Python / FastAPI)

### Module Boundaries

```
app/
├── api/v1/          → REST endpoints, request/response schemas, router
├── ai_engine/       → AI orchestration, providers, prompts, model routing
├── audio_processing/→ Audio pipeline (normalizers, interpreters, scoring)
├── core/            → Config, exceptions, shared constants
├── modules/         → Domain services (sessions, analytics, training, audio_snippets, speech)
├── observability/   → Metrics registry, structured logging
├── queue/           → Async task queue (producers, consumers, tasks)
├── repositories/    → Data access layer (memory, Firestore adapters)
├── storage/         → File storage adapters (audio snippets)
└── workers/         → Background workers (AI evaluation, cleanup)
```

### Layer Flow (strict dependency direction)

```
endpoints → services → repositories
                    → storage
                    → queue producers
```

- Endpoints MUST NOT call repositories directly.
- Services own business logic, validation, and orchestration.
- Repositories are the only layer that touches persistence.
- Cross-module service calls are acceptable for read-only aggregation; avoid write coupling.

### Configuration

- All config flows through `app/core/config.py` via a frozen `Settings` dataclass.
- Every setting uses env vars with sensible defaults.
- Use `_as_bool()` and `_as_csv()` helpers for parsing.
- Never read `os.getenv()` outside `config.py`.

### Error Handling

- Raise `ApiError(code=..., message=..., status_code=...)` for expected failures.
- The global exception handler wraps all errors in the standard envelope:
  ```json
  {"error": {"code": "...", "message": "...", "details": {}, "trace_id": "..."}}
  ```
- Never return raw exceptions or Python tracebacks to clients.

### Schemas (Pydantic v2)

- All request/response models live in `app/api/v1/schemas.py`.
- Use `Field(ge=..., le=..., min_length=...)` constraints on every numeric/string field.
- Use `Literal[...]` for enums (not Python `Enum`).
- Use `model_config = ConfigDict(extra="forbid")` for strict input models.
- Internal domain types use simple dicts or dataclasses; Pydantic is for API boundaries only.

## Mobile Architecture (Flutter / Dart)

### Folder Organization

```
lib/
├── app/             → Bootstrap, DI, router, theme
├── core/            → Audio, auth, config, network, notifications, state, telemetry
├── features/        → Feature modules (clean architecture per feature)
│   └── <feature>/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/          → Cross-feature models, utils, widgets
```

### Feature Module Rules

- Each feature follows `data/domain/presentation` separation.
- Presentation contains pages and widgets only (no business logic).
- Domain contains entities, use cases, and interfaces.
- Data contains repository implementations and data sources.
- Features MUST NOT import from another feature's `data/` or `domain/` directly. Use `shared/` for cross-cutting models.

### State Management

- `ChangeNotifier` with `AppState` as the global app-level state.
- Feature-specific state can use local `ChangeNotifier` or `StatefulWidget` patterns.
- Avoid deeply nested Provider trees; keep it flat.

### Network Layer

- All API calls go through `core/network/api_client.dart`.
- Every method returns a typed DTO (from `shared/models/`).
- Errors throw `ApiException(statusCode, body)`.

### Theme & Design System

- Single source of truth: `app/theme/app_theme.dart`.
- Typography: Sora for headings, Manrope for body.
- Primary: `#0E7C86` (teal). Secondary: `#E1B261` (gold). Background: `#F4F7FB`.
- Card radius: 24. Button/input radius: 16. Button height: 54.
- Use `Theme.of(context)` tokens; never hardcode colors or text styles.
