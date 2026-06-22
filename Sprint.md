# Sprint Roadmap and Execution Log

This file is the single source of truth for sprint planning and status.
Update it after each milestone, merged implementation batch, and validation run.

## How to update this file

- Update sprint status (`planned`, `in_progress`, `completed`) immediately after significant progress.
- Add verification evidence (tests/build/manual checks) in each sprint section.
- Keep implementation checklists actionable and file-oriented.

---

## Sprint 1 - Backend Session Vertical Slice
Status: completed

### Goal
Build core training session APIs end-to-end with auth, metric ingest, finalize, and feedback retrieval.

### Delivered
- Session APIs: create/get/finalize/feedback.
- Metrics ingest endpoint and canonical metric contract.
- Baseline scoring and session completion persistence.

### Key files
- `backend/vocal_coach_api/app/api/v1/endpoints/sessions.py`
- `backend/vocal_coach_api/app/api/v1/endpoints/metrics.py`
- `backend/vocal_coach_api/app/api/v1/endpoints/feedback.py`
- `backend/vocal_coach_api/app/modules/sessions/service.py`

### Validation
- Integration session flow tests passing.

---

## Sprint 2 - Mobile MVP Integration
Status: completed

### Goal
Deliver mobile flow that can authenticate, start session, submit metrics, finalize, and read feedback.

### Delivered
- Flutter app shell with authenticated route gate.
- Training and karaoke pages integrated with backend endpoints.
- Core models and API client wiring.

### Key files
- `mobile/vocal_coach_app/lib/main.dart`
- `mobile/vocal_coach_app/lib/core/network/api_client.dart`
- `mobile/vocal_coach_app/lib/features/**/presentation/*.dart`

### Validation
- Android emulator flow established.

---

## Sprint 3 - AI Orchestration Engine
Status: completed

### Goal
Integrate backend-only AI feedback generation with model routing and fallback safety.

### Delivered
- Ollama provider and model routing.
- Prompt registry with versioning and A/B (`v1a`, `v1b`).
- Structured payload validation and deterministic fallback.

### Key files
- `backend/vocal_coach_api/app/ai_engine/orchestrator/service.py`
- `backend/vocal_coach_api/app/ai_engine/providers/ollama_client.py`
- `backend/vocal_coach_api/app/ai_engine/model_router/service.py`
- `backend/vocal_coach_api/app/ai_engine/prompt_management/templates/*.py`

### Validation
- Unit tests for orchestrator, router, and prompt registry.

---

## Sprint 4 - Observability and Test Hardening
Status: completed

### Goal
Improve reliability diagnostics and expand backend test confidence.

### Delivered
- Standardized error envelope and trace IDs.
- Metrics coverage for AI and queue-related paths.
- Expanded integration and unit tests.

### Key files
- `backend/vocal_coach_api/app/main.py`
- `backend/vocal_coach_api/app/observability/metrics/registry.py`
- `backend/vocal_coach_api/tests/**`

### Validation
- Full backend test suite passing.

---

## Sprint 5 - Analytics Dashboard API
Status: completed

### Goal
Provide user analytics summaries and trend APIs.

### Delivered
- Dashboard endpoint with range summaries.
- Trend points endpoint for 7d/30d/90d.

### Key files
- `backend/vocal_coach_api/app/api/v1/endpoints/analytics.py`
- `backend/vocal_coach_api/app/modules/analytics/service.py`

### Validation
- Analytics integration tests passing.

---

## Sprint 5.1 - Daily Rollup Cache and Trend Seeding
Status: completed

### Goal
Stabilize trend analytics with cached daily rollups and seed spread support.

### Delivered
- Daily rollup cache architecture.
- Seed script spread-days support.

### Key files
- `backend/vocal_coach_api/app/repositories/*/analytics_repository.py`
- `backend/vocal_coach_api/scripts/seed_sessions.py`

### Validation
- Trend population verified with seeded multi-day data.

---

## Sprint 6 - Async AI Queue and Worker
Status: completed

### Goal
Move finalize to non-blocking async queue path.

### Delivered
- In-memory AI queue, producer, consumer, worker loop.
- `finalize` returns `processing` in async mode.
- Worker completes or fails session asynchronously.

### Key files
- `backend/vocal_coach_api/app/queue/tasks/ai_evaluation_queue.py`
- `backend/vocal_coach_api/app/queue/producers/ai_evaluation.py`
- `backend/vocal_coach_api/app/queue/consumers/ai_evaluation.py`
- `backend/vocal_coach_api/app/workers/ai_evaluation_worker.py`

### Validation
- Async integration test coverage (`test_async_queue.py`).

---

## Sprint 7 - Audio Snippet Storage and Governance
Status: completed

### Goal
Persist and govern session audio snippets with retention controls.

### Delivered
- Snippet upload/list/cleanup APIs.
- Local storage adapter + repository support (memory/firestore).
- Retention and size/duration guards.
- Cleanup worker automation.

### Key files
- `backend/vocal_coach_api/app/modules/audio_snippets/service.py`
- `backend/vocal_coach_api/app/api/v1/endpoints/audio_snippets.py`
- `backend/vocal_coach_api/app/storage/audio_snippets/**`
- `backend/vocal_coach_api/app/workers/audio_snippet_cleanup_worker.py`

### Validation
- Audio snippet integration tests passing.

---

## Sprint 8 - AI Reliability and Diagnostics
Status: completed

### Goal
Add AI health observability and fallback reason telemetry.

### Delivered
- AI diagnostics endpoint (`/v1/ai/health`).
- Failure reason classification metrics.
- Better timeout handling and fallback logs.

### Key files
- `backend/vocal_coach_api/app/api/v1/endpoints/ai.py`
- `backend/vocal_coach_api/app/ai_engine/providers/ollama_health.py`
- `backend/vocal_coach_api/app/ai_engine/orchestrator/service.py`

### Validation
- AI health integration tests and orchestrator unit tests updated.

---

## Sprint 9 - Mobile UI/UX and Auth Experience
Status: completed

### Goal
Modernize app UX and complete production-style auth flow.

### Delivered
- Firebase auth screens: welcome/sign in/sign up/forgot-password.
- Auth bootstrap and guarded app entry.
- Design system baseline and screen polish.

### Key files
- `mobile/vocal_coach_app/lib/features/authentication/presentation/*.dart`
- `mobile/vocal_coach_app/lib/core/state/app_state.dart`
- `mobile/vocal_coach_app/lib/app/theme/app_theme.dart`

### Validation
- `dart analyze` clean.

---

## Sprint 10 - Vocal Coach Training Architecture and Workflow
Status: completed

### Goal
Finish complete Vocal Coach training architecture/workflow before moving to next sprint.

### Delivered so far
- Non-blocking AI queue UX with always-on system notifications.
- AI jobs lifecycle API and queue page.
- Live microphone-based pitch/loudness analyzer integrated into training screen.
- Vocal Coach category and exercise hub with populated tracks:
  - Vocal Training
  - Do Re Mi Pitch
  - Breathing Exercises
- Open-access recommendation flow for Vocal Coach with `Today's Focus`, recommendation cards, and richer track/exercise cards.
- Exercise briefing screen added before live sessions to lock session setup cleanly.
- Exercise-specific backend spec, runtime plan, weighted scoring, and AI prompt context implemented for Vocal Training-first architecture.
- Do Re Mi and Breathing now use the same exercise-spec/runtime/scoring architecture as Vocal Training.
- Live session UX now includes animated guided-step rendering, countdown ring, and light haptic feedback cues.
- Vocal Coach copy and setup flow were revised for clarity, with breathing drills repositioned as timer-guided no-mic exercises.

### Key files (current)
- Backend
  - `backend/vocal_coach_api/app/api/v1/endpoints/ai.py`
  - `backend/vocal_coach_api/app/api/v1/endpoints/sessions.py`
  - `backend/vocal_coach_api/app/modules/sessions/service.py`
  - `backend/vocal_coach_api/app/modules/training/scoring.py`
  - `backend/vocal_coach_api/app/queue/consumers/ai_evaluation.py`
- Mobile
  - `mobile/vocal_coach_app/lib/app/theme/app_theme.dart`
  - `mobile/vocal_coach_app/lib/core/audio/live_audio_analyzer.dart`
  - `mobile/vocal_coach_app/lib/features/vocal_training/domain/vocal_coach_catalog.dart`
  - `mobile/vocal_coach_app/lib/features/vocal_training/presentation/exercise_briefing_page.dart`
  - `mobile/vocal_coach_app/lib/features/vocal_training/presentation/vocal_training_page.dart`
  - `mobile/vocal_coach_app/lib/features/vocal_training/presentation/training_session_page.dart`
  - `mobile/vocal_coach_app/lib/features/ai_feedback_display/presentation/analysis_queue_page.dart`

### Implementation checklist (completed)

#### Backend
1. [x] `backend/vocal_coach_api/app/modules/training/catalog.py` (new)
   - Move exercise catalog to backend source-of-truth with category metadata and thresholds.
2. [x] `backend/vocal_coach_api/app/modules/training/service.py` (new)
   - Catalog read APIs, exercise validation, and per-exercise progress aggregation.
3. [x] `backend/vocal_coach_api/app/api/v1/endpoints/training.py` (new)
   - Add `GET /v1/training/catalog`, `GET /v1/training/progress`, `GET /v1/training/recommendations`.
4. [x] `backend/vocal_coach_api/app/api/v1/router.py`
   - Register training router.
5. [x] `backend/vocal_coach_api/app/api/v1/schemas.py`
   - Add training catalog/progress/recommendation response schemas.
6. [x] `backend/vocal_coach_api/app/modules/sessions/service.py`
   - Persist training category/exercise/session config snapshot in sessions.
   - Save weighted attempts with best-attempt context.
7. [x] `backend/vocal_coach_api/app/ai_engine/prompt_management/templates/v1*.py`
   - Inject category/exercise context and live signal summaries into AI prompt.
8. [x] `backend/vocal_coach_api/app/modules/training/scoring.py` (new)
   - Add exercise-weighted attempt scoring and threshold classification.
9. [x] `contracts/api/openapi/vocal_coach_v1.yaml`
   - Add training endpoints and updated session payload schemas.

#### Mobile
1. [x] `mobile/vocal_coach_app/lib/shared/models/training_models.dart` (new)
   - DTOs for backend-driven catalog/progress/recommendations.
2. [x] `mobile/vocal_coach_app/lib/core/network/api_client.dart`
   - Add training catalog/progress/recommendation methods.
3. [x] `mobile/vocal_coach_app/lib/features/vocal_training/presentation/vocal_training_page.dart`
   - Fetch and render backend catalog + progress + recommendations (use local catalog as fallback).
4. [x] `mobile/vocal_coach_app/lib/features/vocal_training/presentation/exercise_briefing_page.dart` (new)
   - Add guided briefing/setup screen before session start.
5. [x] `mobile/vocal_coach_app/lib/features/vocal_training/presentation/training_session_page.dart`
    - [x] Replace manual metric-only trigger with timed attempt auto-save workflow.
    - [x] Add key/octave selector and adaptive loudness calibration workflow.
    - [x] Render runtime pattern guidance, focused review summary, and cleaner session UX.
    - [x] Add animated live stepper, countdown ring, and light haptics.
6. [x] `mobile/vocal_coach_app/lib/features/analytics_dashboard/presentation/analytics_dashboard_page.dart`
   - Add per-exercise progress widgets from training progress endpoint.

### Validation checklist
- Backend: `python3 -m pytest tests/unit tests/integration -q`.
- Mobile: `dart analyze` and `flutter build apk --debug`.
- Manual: exercise start -> live coach -> queue finalize -> notification -> feedback -> progress update.
- Note: real-device singing calibration/tuning pass is still pending and is carried into Sprint 11.

### Sprint 10 closeout
- Engineering closure: complete.
- Automated validation: complete.
- Product/device sign-off: still requires a real singing pass on hardware and cannot be fully executed from CLI.

### Latest automated validation evidence
- 2026-03-18: `python3 -m pytest tests/unit tests/integration -q` -> `38 passed`.
- 2026-03-18: `dart analyze` -> clean.
- 2026-03-18: `flutter build apk --debug` -> success.
- 2026-03-18: `flutter test` -> blocked by missing local `flutter_tester` engine artifact, not by Sprint 10 feature code.

### Manual sign-off checklist
- Core Vocal Training
  - `Resonance Placement`: verify calibration, sustain-stage pacing, best-attempt selection, finalize, feedback, analytics update.
  - `Pitch Warmup`: verify ladder transitions, note targeting, cue fairness, finalize, feedback, analytics update.
  - `Note Transition Drill`: verify transition pacing, stage/haptic sync, score fairness, finalize, feedback, analytics update.
- Cross-track smoke tests
  - `Do Re Mi -> Basic Ladder`: verify category navigation, runtime stage rendering, finalize, progress update.
  - `Breathing -> Support Ladder`: verify sustain guidance, breath scoring feel, finalize, progress update.
- Edge cases
  - mic permission denied
  - calibration failure / retry
  - finalize without attempts blocked
  - max attempts enforced at 3
  - async AI queue refresh + notification handoff

### Progress log
- 2026-03-18: Created Sprint.md as canonical sprint tracker; moved sprint planning ownership here.
- 2026-03-18: Batch 1 completed (backend training catalog/progress/recommendation APIs + schema/router wiring + OpenAPI updates).
- 2026-03-18: Batch 1 mobile integration completed (training models, API client methods, Vocal Coach page now backend-catalog-driven with fallback and correct hierarchy).
- 2026-03-18: Validation completed for this batch: backend tests `31 passed`; mobile `dart analyze` clean; `flutter build apk --debug` successful.
- 2026-03-18: Added Analytics training progress section backed by `GET /v1/training/progress` and rendered top per-exercise stats.
- 2026-03-18: Re-validated mobile app after analytics integration: `dart analyze` clean; `flutter build apk --debug` successful.
- 2026-03-18: Completed training session runtime enhancements: key/octave selectors, transposed target frequency computation, and loudness floor calibration workflow.
- 2026-03-18: Re-validated mobile app after training session enhancements: `dart analyze` clean; `flutter build apk --debug` successful.
- 2026-03-18: Implemented Vocal Coach open-access recommendation architecture with richer backend exercise specs, runtime plans, weighted scoring, and AI prompt context.
- 2026-03-18: Implemented new mobile Vocal Coach UX pass: premium home hero, recommended drill cards, exercise briefing screen, upgraded training session review/runtime panels, and refreshed app typography/theme.
- 2026-03-18: Re-validated implementation pass: backend tests `36 passed`; mobile `dart analyze` clean; `flutter build apk --debug` successful.
- 2026-03-18: Extended the exercise-spec architecture across Do Re Mi and Breathing with tuned pacing data in the shared backend catalog.
- 2026-03-18: Added animated live session stepper, countdown ring, and light haptic feedback polish to the training session experience.
- 2026-03-18: Re-validated polish pass: backend tests `38 passed`; mobile `dart analyze` clean; `flutter build apk --debug` successful.
- 2026-03-18: Sprint 10 implementation scope completed in code and automated validation; remaining real-device tuning moved to Sprint 11.
- 2026-03-18: Sprint 10 closeout pass completed from engineering side: backend tests re-run (`38 passed`), `dart analyze` clean, APK build successful, and `flutter test` confirmed blocked by missing local `flutter_tester` artifact rather than feature regressions.
- 2026-03-18: Revised exercise guidance UX so first-time users see clearer `what you do` context, mic requirements, and breathing exercises now run as timer-guided no-mic routines.

---

## Sprint 11 - Thesis Alignment Comprehensive
Status: planned

### Goal
Align the system with all thesis documentation deliverables. Implement missing modules (Guest Access, Premium Tier, Karaoke Catalog, Profile/Vocal Preferences), enhance existing modules (Dashboard, Karaoke end-to-end), verify existing features (Voice Room, Coaching, Progress Tracking, AI Engine), and remove out-of-scope features (Diction/Pronunciation from original Sprint 11 plan). Ensure ISO 25010 compliance readiness for thesis defense.

### Rationale
- The thesis documents six modules: Account, Dashboard, Voice Room, Coaching/Tutorial, Karaoke, Progress Tracking.
- The original Sprint 11 (Diction/Pronunciation) is NOT part of the thesis scope and was removed.
- Guest mode, Premium tier, Karaoke song catalog, and Profile vocal preferences are documented in the thesis but not yet implemented.
- The system must pass ISO 25010 evaluation by 42 respondents (10 IT instructors, 2 vocal coaches, 30 aspiring singers).

### Spec location
- `.kiro/specs/thesis-alignment-comprehensive/requirements.md` (13 requirements)
- `.kiro/specs/thesis-alignment-comprehensive/design.md` (architecture, data models, 22 correctness properties)
- `.kiro/specs/thesis-alignment-comprehensive/tasks.md` (43 tasks in 13 groups)

### Key files (planned)
- Backend
  - `backend/vocal_coach_api/app/modules/users/service.py` (new)
  - `backend/vocal_coach_api/app/modules/karaoke/catalog.py` (new)
  - `backend/vocal_coach_api/app/modules/karaoke/service.py` (new)
  - `backend/vocal_coach_api/app/api/v1/endpoints/profile.py` (new)
  - `backend/vocal_coach_api/app/api/v1/endpoints/karaoke.py` (new)
  - `backend/vocal_coach_api/app/api/v1/schemas.py` (enhanced)
  - `backend/vocal_coach_api/app/queue/tasks/ai_evaluation_queue.py` (enhanced)
- Mobile
  - `mobile/vocal_coach_app/lib/shared/models/karaoke_models.dart` (new)
  - `mobile/vocal_coach_app/lib/features/karaoke_practice/presentation/karaoke_catalog_page.dart` (new)
  - `mobile/vocal_coach_app/lib/features/karaoke_practice/presentation/karaoke_song_briefing_page.dart` (new)
  - `mobile/vocal_coach_app/lib/features/user_profile/presentation/vocal_preferences_page.dart` (new)
- Contracts
  - `contracts/api/openapi/vocal_coach_v1.yaml` (updated)

### Progress log
- 2026-06-22: Sprint 11 scope changed from Diction/Pronunciation to Thesis Alignment Comprehensive. Original Sprint 11 content removed as out-of-thesis-scope.
- 2026-06-22: Full spec created (requirements, design, tasks) at `.kiro/specs/thesis-alignment-comprehensive/`. 13 requirements, 22 correctness properties, 43 implementation tasks defined.
- 2026-06-22: Kiro hooks (10) and steering files (7) created for consistent coding throughout implementation.
- 2026-06-22: Added OpenRouter provider as alternative to Ollama for client demo/presentation use. Cascade: OpenRouter → Ollama → deterministic fallback. Backend imports verified clean.

---

## [REMOVED] Sprint 11 (Original) - Diction, Pronunciation, and Phrase Clarity
Status: cancelled (out of thesis scope)

### [REMOVED] Original Sprint 11 Rationale (preserved for reference)
- Pitch, breath, and transitions do not fully cover lyric clarity, articulation, and understandable delivery.
- This was planned as a post-thesis extension and is NOT part of the thesis evaluation scope.
- All diction/pronunciation/phrase-clarity work has been deferred to post-defense development.


