# Implementation Plan: Thesis Alignment Comprehensive

## Overview

This plan implements the thesis alignment features across 9 logical groups: backend schemas/models, backend services, backend endpoints, backend tests, mobile models/API client, mobile feature implementations, mobile state/integration, Sprint 11 removal, and final validation. Each task builds incrementally on the previous, ensuring no orphaned code. The backend uses Python 3.11+ FastAPI with Pydantic v2; mobile uses Flutter/Dart.

## Tasks

- [x] 1. Backend schemas and data models (foundation)
  - [x] 1.1 Add profile and access tier schemas to `backend/vocal_coach_api/app/api/v1/schemas.py`
    - Add `AccessTier`, `VocalRange`, `TrainingGoal` Literal types
    - Add `VocalPreferencesIn`, `VocalPreferencesOut`, `UserProfileOut` Pydantic models
    - Add premium-related fields: `premium_expires_at`, `access_tier`
    - _Requirements: 2.1, 3.1, 3.2, 3.5_

  - [x] 1.2 Add karaoke catalog schemas to `backend/vocal_coach_api/app/api/v1/schemas.py`
    - Add `KaraokeDifficulty`, `KaraokeSongOut`, `KaraokeCategoryOut`, `KaraokeCatalogOut` models
    - Enforce field constraints: `duration_sec` 30–180, `tempo_bpm` 40–220, min 3 categories
    - _Requirements: 7.1, 7.6, 13.1, 13.2_

  - [x] 1.3 Add AI queue priority field to `backend/vocal_coach_api/app/queue/tasks/ai_evaluation_queue.py`
    - Add `priority: int` field to the queue item model (1=premium, 2=registered)
    - Modify dequeue logic to select lowest priority first, FIFO within same priority
    - _Requirements: 2.4_

- [x] 2. Backend services (business logic)
  - [x] 2.1 Implement profile service in `backend/vocal_coach_api/app/modules/users/service.py`
    - Implement `get_user_profile(user_id)` returning full profile with access tier and preferences
    - Implement `update_vocal_preferences(user_id, preferences)` with validation and persistence
    - Implement `upgrade_to_premium(user_id)` with idempotent tier change and expiry tracking
    - Implement `get_access_tier(user_id)` returning guest/registered/premium
    - Add retention policy logic: 365 days for premium, 90 days for registered
    - Preserve premium-period sessions on downgrade
    - _Requirements: 2.1, 2.2, 2.3, 2.6, 2.7, 3.2, 3.3, 3.4_

  - [x] 2.2 Create karaoke catalog data in `backend/vocal_coach_api/app/modules/karaoke/catalog.py` (new)
    - Define static karaoke catalog with minimum 3 categories (distinct style labels)
    - Each category has at least 1 song with full metadata (title, artist, difficulty, tempo, vocal range, tips)
    - Follow the same pattern as `training/catalog.py`
    - _Requirements: 7.1, 7.6, 13.1, 13.2_

  - [x] 2.3 Implement karaoke service in `backend/vocal_coach_api/app/modules/karaoke/service.py` (new)
    - Implement `get_karaoke_catalog()` returning the full catalog
    - Implement `get_song_by_id(song_id)` returning a single song or None
    - Implement `list_songs_by_category(category)` for filtered retrieval
    - _Requirements: 7.1, 13.1, 13.3_

  - [x] 2.4 Enhance recommendation filtering in `backend/vocal_coach_api/app/modules/training/service.py`
    - Modify recommendation logic to filter by user's `preferred_categories` and `vocal_range`
    - Fall back to performance-based recommendations if no preferences are set
    - _Requirements: 3.6, 3.7_

  - [x] 2.5 Enhance AI queue producer in `backend/vocal_coach_api/app/queue/producers/ai_evaluation.py`
    - Pass user's access tier to queue item as priority field
    - Premium users get priority=1, registered users get priority=2
    - _Requirements: 2.4_

- [x] 3. Backend API endpoints (API layer)
  - [x] 3.1 Create profile endpoint in `backend/vocal_coach_api/app/api/v1/endpoints/profile.py` (new)
    - `GET /v1/profile` — return full user profile with access tier and vocal preferences
    - `PATCH /v1/profile/preferences` — validate and update vocal preferences
    - `POST /v1/profile/upgrade` — upgrade user to premium tier
    - Apply Firebase Auth dependency for all routes
    - _Requirements: 2.2, 3.1, 3.2, 3.3, 3.4, 10.4_

  - [x] 3.2 Create karaoke endpoint in `backend/vocal_coach_api/app/api/v1/endpoints/karaoke.py` (new)
    - `GET /v1/karaoke/catalog` — return full karaoke catalog
    - `GET /v1/karaoke/catalog/{song_id}` — return single song detail (404 if not found)
    - Apply Firebase Auth dependency
    - _Requirements: 7.1, 13.1, 13.3_

  - [x] 3.3 Register new routers in `backend/vocal_coach_api/app/api/v1/router.py`
    - Import and include `profile_router` and `karaoke_router`
    - _Requirements: 10.1_

  - [x] 3.4 Add guest catalog access parameter to training endpoint `backend/vocal_coach_api/app/api/v1/endpoints/training.py`
    - Add optional `?guest=true` query parameter to `GET /v1/training/catalog`
    - When guest=true, return catalog metadata without session-creation capability
    - Allow unauthenticated access for catalog browsing only
    - _Requirements: 1.1, 1.2_

- [x] 4. Checkpoint - Backend foundation verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Backend tests (verification)
  - [x] 5.1 Create unit tests for profile service in `backend/vocal_coach_api/tests/unit/test_profile_service.py` (new)
    - Test `get_user_profile` returns correct profile structure
    - Test `update_vocal_preferences` accepts valid payloads and rejects invalid
    - Test `upgrade_to_premium` changes tier and sets expiry
    - Test `get_access_tier` returns correct tier for each user state
    - Test retention policy: 365 days premium, 90 days registered
    - Test downgrade preserves premium-period sessions
    - _Requirements: 2.1, 2.2, 2.3, 2.7, 3.2, 3.3, 3.4_

  - [x] 5.2 Create unit tests for karaoke service in `backend/vocal_coach_api/tests/unit/test_karaoke_service.py` (new)
    - Test catalog returns minimum 3 categories with distinct style labels
    - Test each category has at least 1 song
    - Test `get_song_by_id` returns correct song or None
    - Test song metadata validity (duration, tempo, vocal range fields)
    - _Requirements: 7.1, 7.6, 13.1, 13.2_

  - [x] 5.3 Create unit tests for AI queue priority in `backend/vocal_coach_api/tests/unit/test_queue_priority.py` (new)
    - Test premium requests dequeue before registered requests submitted after them
    - Test FIFO ordering within same priority tier
    - Test mixed queue sequences
    - _Requirements: 2.4_

  - [x] 5.4 Create integration tests for profile endpoints in `backend/vocal_coach_api/tests/integration/test_profile_endpoints.py` (new)
    - Test GET /v1/profile returns full profile
    - Test PATCH /v1/profile/preferences with valid and invalid payloads
    - Test POST /v1/profile/upgrade changes tier
    - Test 401 for unauthenticated requests
    - Test 422 for invalid preference values
    - _Requirements: 2.2, 3.1, 3.2, 3.3, 3.4, 10.3, 10.4_

  - [x] 5.5 Create integration tests for karaoke endpoints in `backend/vocal_coach_api/tests/integration/test_karaoke_endpoints.py` (new)
    - Test GET /v1/karaoke/catalog returns valid catalog structure
    - Test GET /v1/karaoke/catalog/{song_id} returns song or 404
    - Test 401 for unauthenticated requests
    - _Requirements: 7.1, 13.1, 13.3, 10.4_

  - [ ]* 5.6 Create property-based tests in `backend/vocal_coach_api/tests/property/test_thesis_properties.py` (new)
    - **Property 4: Priority queue ordering** — generate random queue sequences, verify dequeue order
    - **Validates: Requirements 2.4**

  - [ ]* 5.7 Add property tests for vocal preference validation in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 7: Vocal preference validation** — generate random payloads, verify accept/reject
    - **Validates: Requirements 3.2, 3.5**

  - [ ]* 5.8 Add property tests for preference round-trip in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 8: Vocal preference persistence round-trip** — valid preferences persist and return unchanged
    - **Validates: Requirements 3.3**

  - [ ]* 5.9 Add property tests for invalid preferences preservation in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 9: Invalid preferences preserve existing state** — invalid payloads don't modify stored data
    - **Validates: Requirements 3.4**

  - [ ]* 5.10 Add property tests for preference-filtered recommendations in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 10: Preference-filtered recommendations** — all recommendations match user's preferred_categories
    - **Validates: Requirements 3.6**

  - [ ]* 5.11 Add property tests for dashboard recent sessions in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 11: Dashboard recent evaluations** — returns top 3 most recent sessions ordered newest-first
    - **Validates: Requirements 4.2**

  - [ ]* 5.12 Add property tests for max attempts enforcement in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 12: Maximum attempts enforcement** — accepts attempts 1..N, rejects > N
    - **Validates: Requirements 5.4**

  - [ ]* 5.13 Add property tests for AI feedback constraints in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 13: AI feedback output constraints** — verify output structure bounds
    - **Validates: Requirements 7.4, 12.1, 12.4**

  - [ ]* 5.14 Add property tests for AI fallback in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 14: AI fallback on unreachable model** — returns valid feedback with model_used="fallback-rules"
    - **Validates: Requirements 12.3**

  - [ ]* 5.15 Add property tests for best attempt selection in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 15: Best attempt metrics for multi-attempt evaluation** — uses highest-score attempt
    - **Validates: Requirements 12.5**

  - [ ]* 5.16 Add property tests for catalog scope constraint in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 17: Training catalog contains only thesis-documented categories** — no diction/pronunciation
    - **Validates: Requirements 9.1, 9.4**

  - [ ]* 5.17 Add property tests for karaoke catalog structure in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 18: Karaoke catalog structural validity** — min 3 categories, distinct labels, each has songs
    - **Validates: Requirements 7.1, 13.1**

  - [ ]* 5.18 Add property tests for karaoke song metadata in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 19: Karaoke song metadata validity** — all field constraints met
    - **Validates: Requirements 7.6, 13.2**

  - [ ]* 5.19 Add property tests for input validation in `backend/vocal_coach_api/tests/property/test_thesis_properties.py`
    - **Property 22: Input validation rejects malformed requests** — out-of-range values get 422
    - **Validates: Requirements 10.3**

- [x] 6. Checkpoint - Backend tests passing
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Mobile models and API client (data layer)
  - [x] 7.1 Create karaoke models in `mobile/vocal_coach_app/lib/shared/models/karaoke_models.dart` (new)
    - Define `KaraokeSong`, `KaraokeCategory`, `KaraokeCatalog` DTOs with `fromJson` factories
    - Include all metadata fields: songId, title, styleCategory, difficulty, durationSec, artistReference, tempoBpm, vocalRangeLow, vocalRangeHigh, objective, performanceTips
    - _Requirements: 7.6, 13.2_

  - [x] 7.2 Enhance user models in `mobile/vocal_coach_app/lib/shared/models/user_models.dart`
    - Add `AccessTier` enum (guest, registered, premium)
    - Add `VocalRange` enum with six classifications
    - Add `TrainingGoal` enum with five values
    - Add `VocalPreferences` class with `fromJson`/`toJson`
    - Add `UserProfileFull` class with accessTier, vocalPreferences, premiumExpiresAt
    - Add `VocalPreferencesUpdate` class for PATCH payload
    - _Requirements: 2.1, 3.1, 3.2, 3.5_

  - [x] 7.3 Extend API client in `mobile/vocal_coach_app/lib/core/network/api_client.dart`
    - Add `fetchKaraokeCatalog()` method → `GET /v1/karaoke/catalog`
    - Add `fetchKaraokeSong({required String songId})` → `GET /v1/karaoke/catalog/{songId}`
    - Add `fetchFullProfile()` → `GET /v1/profile`
    - Add `updateVocalPreferences(VocalPreferencesUpdate prefs)` → `PATCH /v1/profile/preferences`
    - Add `upgradeToPremium()` → `POST /v1/profile/upgrade`
    - _Requirements: 3.3, 7.1, 13.3_

- [x] 8. Mobile feature implementations (UI/UX)
  - [x] 8.1 Implement karaoke catalog page in `mobile/vocal_coach_app/lib/features/karaoke_practice/presentation/karaoke_catalog_page.dart` (new)
    - Fetch karaoke catalog from backend via API client
    - Display categories with style labels and song cards
    - Show song metadata: title, difficulty, duration, artist reference
    - Handle loading, error, and empty states
    - Navigate to song briefing on tap
    - _Requirements: 7.1, 13.1, 13.2, 13.3, 13.5_

  - [x] 8.2 Implement karaoke song briefing page in `mobile/vocal_coach_app/lib/features/karaoke_practice/presentation/karaoke_song_briefing_page.dart` (new)
    - Display: song title, style category, difficulty, duration, objective, performance tips
    - Show vocal range information (low–high)
    - Provide "Start Session" button that creates a karaoke session
    - _Requirements: 13.4_

  - [x] 8.3 Update karaoke practice page in `mobile/vocal_coach_app/lib/features/karaoke_practice/presentation/karaoke_practice_page.dart`
    - Route through catalog → briefing → session flow instead of direct session start
    - Integrate with updated karaoke catalog navigation
    - _Requirements: 7.2_

  - [x] 8.4 Implement vocal preferences page in `mobile/vocal_coach_app/lib/features/user_profile/presentation/vocal_preferences_page.dart` (new)
    - Form with vocal range dropdown (6 options), category multi-select (max 3), training goal dropdown
    - Client-side validation matching backend constraints
    - Submit to API client `updateVocalPreferences`
    - Handle success confirmation and error display (field-level)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 8.5 Enhance user profile page in `mobile/vocal_coach_app/lib/features/user_profile/presentation/user_profile_page.dart`
    - Display full profile: name, email, access tier badge, vocal preferences summary
    - Add "Edit Preferences" navigation to vocal preferences page
    - Add premium upgrade CTA if user is registered tier
    - Show premium expiry date if premium
    - _Requirements: 3.1, 2.1, 2.2_

  - [x] 8.6 Enhance home dashboard page in `mobile/vocal_coach_app/lib/features/home_dashboard/presentation/`
    - Add progress summary card: total sessions, streak days, 7-day average score
    - Add recent evaluations section showing 3 most recent sessions (exercise name, score, timestamp)
    - Add personalized recommendation card from training recommendations
    - Add quick-access navigation cards to all thesis modules
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 9. Checkpoint - Mobile feature structure verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Mobile state and integration
  - [x] 10.1 Enhance app state for access tiers in `mobile/vocal_coach_app/lib/core/state/app_state.dart`
    - Add `isGuest` getter (true when not authenticated)
    - Add `accessTier` getter resolving from user profile
    - Add guest mode feature restriction logic
    - Track authenticated user's premium status
    - _Requirements: 1.1, 1.2, 2.1_

  - [x] 10.2 Implement guest access restrictions across feature pages
    - Show lock indicators on restricted features (sessions, progress, AI feedback) when guest
    - Display registration prompt on Dashboard in guest mode
    - Navigate to registration flow with feature name when guest taps restricted feature
    - _Requirements: 1.2, 1.3, 1.4_

  - [x] 10.3 Wire karaoke catalog navigation in app routing
    - Update app router to include karaoke catalog and briefing routes
    - Connect bottom navigation karaoke tab to catalog page
    - Ensure back navigation works through catalog → briefing → session flow
    - _Requirements: 7.1, 7.2_

  - [x] 10.4 Add error handling for catalog load failures in karaoke and training pages
    - Show "Catalog temporarily unavailable" error state with retry action
    - Apply to both training catalog (guest mode) and karaoke catalog
    - _Requirements: 1.5, 13.5_

- [x] 11. Sprint 11 removal and scope cleanup
  - [x] 11.1 Verify training catalog excludes Sprint 11 content in `backend/vocal_coach_api/app/modules/training/catalog.py`
    - Confirm no diction, pronunciation, or phrase clarity exercises exist in catalog
    - Confirm only Vocal Training, Do Re Mi Pitch, and Breathing Exercises categories present
    - Add a code comment documenting the scope constraint
    - _Requirements: 9.1, 9.4_

  - [x] 11.2 Remove Sprint 11 planned artifacts from mobile build
    - Verify no diction/pronunciation widgets, models, or routes exist in the compiled feature set
    - Verify Sprint 11 planned scope in Sprint.md does not produce runtime artifacts
    - Confirm no Whisper/transcription references in mobile code
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 11.3 Update `contracts/api/openapi/vocal_coach_v1.yaml` with new endpoints
    - Add profile endpoints (GET, PATCH, POST) schemas
    - Add karaoke catalog endpoints (GET catalog, GET song) schemas
    - Add AccessTier, VocalPreferences, KaraokeCatalog response models
    - _Requirements: 10.1, 10.5_

- [x] 12. Final validation and ISO 25010 verification
  - [x] 12.1 Create smoke test script in `backend/vocal_coach_api/tests/integration/test_smoke_thesis_modules.py` (new)
    - Verify all six thesis module endpoints respond (auth, sessions, training, karaoke, analytics, profile)
    - Verify no Sprint 11 artifacts accessible via API
    - Verify karaoke catalog returns non-empty response
    - Verify training catalog contains only thesis categories
    - _Requirements: 9.1, 10.1_

  - [x] 12.2 Verify ISO 25010 compliance evidence across the codebase
    - Confirm modular architecture: API → service → repository separation
    - Confirm input validation on all new endpoints (Pydantic constraints + 422 responses)
    - Confirm Firebase Auth enforcement on all protected routes
    - Confirm error envelope consistency with `trace_id`
    - Confirm loading states and Material Design navigation patterns in mobile
    - _Requirements: 10.2, 10.3, 10.4, 10.5, 10.6_

- [x] 13. Final checkpoint - Full system validation
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical boundaries
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The backend uses Python (Hypothesis) for property-based tests
- All new endpoints follow the existing layer flow: endpoints → services → repositories
- Sprint 11 removal is verification-only — no code deletion needed since Sprint 11 was never implemented

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.5"] },
    { "id": 2, "tasks": ["2.3", "2.4", "7.1", "7.2"] },
    { "id": 3, "tasks": ["3.1", "3.2", "3.4", "7.3"] },
    { "id": 4, "tasks": ["3.3", "5.1", "5.2", "5.3"] },
    { "id": 5, "tasks": ["5.4", "5.5", "5.6", "5.7", "5.8", "5.9"] },
    { "id": 6, "tasks": ["5.10", "5.11", "5.12", "5.13", "5.14", "5.15"] },
    { "id": 7, "tasks": ["5.16", "5.17", "5.18", "5.19"] },
    { "id": 8, "tasks": ["8.1", "8.2", "8.4", "8.5"] },
    { "id": 9, "tasks": ["8.3", "8.6", "10.1"] },
    { "id": 10, "tasks": ["10.2", "10.3", "10.4"] },
    { "id": 11, "tasks": ["11.1", "11.2", "11.3"] },
    { "id": 12, "tasks": ["12.1", "12.2"] }
  ]
}
```
