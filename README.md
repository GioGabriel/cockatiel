# Cockatiel Vocal Coach

Cockatiel is a Flutter vocal-practice app backed by a FastAPI service. It guides
aspiring singers through short exercises and karaoke practice with local live
audio feedback, deterministic coaching, and an optional OpenRouter summary.

The deterministic `CoachingLogicEngine` is the product authority for scores,
strengths, improvements, and next exercises. Remote AI is an enhancement, not a
dependency: provider outages, missing keys, timeouts, and invalid responses must
still produce complete coaching feedback.

## Repository layout

- `mobile/vocal_coach_app/` — Flutter client for Android and supported local web/Chrome smoke testing.
- `backend/vocal_coach_api/` — FastAPI API, domain services, workers, and persistence adapters.
- `contracts/` — checked-in OpenAPI contract and cross-layer API vocabulary.
- `docs/` — architecture, product decisions, quality gates, and operational notes.
- `.github/workflows/quality.yml` — CI-compatible formatting, static-analysis, contract, test, and build checks.

## Local backend

From `backend/vocal_coach_api`:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -e ".[dev,firestore]"
uvicorn app.main:app --reload --port 8000
```

The convenience script fails closed by default. For a local-only synthetic
identity, opt in explicitly:

```bash
AUTH_BYPASS=true bash scripts/run_backend.sh
```

Never use that mode in staging or production. Production should set
`APP_ENV=production`, keep `AUTH_BYPASS=false`, configure Firebase Admin
credentials through protected environment injection, and set explicit
`CORS_ALLOWED_ORIGINS` values. Enable Firestore with valid production
credentials; the backend refuses to silently use in-memory persistence in
production. Keep `API_REQUEST_TIMEOUT_S` bounded. Do not print or commit
credentials.

The Render blueprint intentionally does not allow localhost origins in
production. Set the deployed web-client origin explicitly in the Render
environment as `CORS_ALLOWED_ORIGINS`; this does not bypass Firebase
authentication. Local Chrome smoke testing should use a separate local API
process and local CORS configuration, never a production allowlist.

Production never serves the built-in metadata-only sample karaoke catalog. If
Firestore is disabled, empty, or unavailable, the API returns an empty catalog
or a safe unavailable error rather than presenting demo songs. Production audio
storage also fails closed instead of falling back to ephemeral local disk.

OpenRouter is optional. The canonical setting is `OPENROUTER_API_KEYS`; the
legacy singular `OPENROUTER_API_KEY` is accepted only as a migration fallback.
The backend never logs key values.

## Local Flutter client

The validated local toolchain is Flutter `3.47.2` stable (Dart `3.13.2`).
Android Studio and an emulator are not required for the browser workflow.

From `mobile/vocal_coach_app`:

```bash
flutter pub get
flutter run -d chrome
```

For a local API endpoint:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Release builds reject non-local HTTP endpoints and development auth/emulator
switches. Chrome is useful for UI smoke testing, but microphone and audio
behavior must also be checked on a representative Android device.

An Android APK build needs the Android SDK, platform tools, build tools, and the
project NDK; Android Studio and an emulator are optional. Run
`flutter build apk --release` only after `ANDROID_SDK_ROOT` is configured.

## Verification

Backend checks:

```bash
cd backend/vocal_coach_api
pytest -q
python3 -m compileall -q app tests
ruff check app tests
pytest --cov=app --cov-report=term-missing
```

Flutter checks, when the Flutter SDK is installed:

```bash
cd mobile/vocal_coach_app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test --coverage
flutter build web --release
```

See [`docs/engineering/quality-gates.md`](docs/engineering/quality-gates.md) for
the risk-based verification policy and
[`docs/product/design-system.md`](docs/product/design-system.md) for the visual-system rules.
