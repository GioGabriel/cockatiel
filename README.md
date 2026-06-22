# Vocal Coach Monorepo

AI-powered vocal coaching platform with Flutter mobile app + FastAPI backend + Ollama feedback engine.

## Repo structure
- `mobile/` Flutter application
- `backend/` FastAPI API + AI orchestration + analytics
- `contracts/` shared schemas/OpenAPI
- `docs/` architecture and product docs
- `infra/` deployment/monitoring placeholders

## One-time setup

### 1) Backend dependencies
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/backend/vocal_coach_api
pip install -e ".[dev,firestore]"
```

### 2) Mobile dependencies
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/mobile/vocal_coach_app
flutter pub get
```

### 3) Firebase mobile config (already done once)
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/mobile/vocal_coach_app
flutterfire configure --project=cockatiel-enhanced --platforms=android,ios --yes
```

Expected generated files:
- `mobile/vocal_coach_app/lib/firebase_options.dart`
- `mobile/vocal_coach_app/android/app/google-services.json`
- `mobile/vocal_coach_app/ios/Runner/GoogleService-Info.plist`

### 4) Android toolchain sanity
```bash
flutter doctor --android-licenses
flutter doctor -v
```

## Run locally (Android-first)

Use 3 terminals.

### One-command option
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced
bash .script/run-all-android.sh
```

Useful toggles:
- `RUN_FLUTTER=false` prepare services without launching app
- `START_BACKEND=false` keep existing backend process
- `START_OLLAMA=false` skip Ollama startup
- `OLLAMA_START_MODE=serve|service` choose `ollama serve` (default) or `brew services`
- `OLLAMA_LOG_FILE=/path/to/ollama.log` set log file for `ollama serve`
- `OLLAMA_MODELS=llama3:latest` set backend model candidates
- `OLLAMA_TIMEOUT_S=180` set per-model Ollama timeout seconds
- `START_EMULATOR=false` use already running emulator
- `DEVICE_ID=emulator-5554` force a specific emulator id
- `EMULATOR_NAME=Pixel_6a` choose emulator name for launch
- `BACKEND_START_SCRIPT=scripts/run_backend.sh` force inline finalize mode
- `FLUTTER_EXTRA_ARGS='--dart-define=USE_FIREBASE_AUTH_EMULATOR=true'` pass extra `flutter run` args

### Terminal A: Start Ollama (if not using one-command launcher)
```bash
ollama serve
ollama list
```

The one-command launcher starts `ollama serve` automatically by default.

### Terminal B: Start backend (async recommended)
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/backend/vocal_coach_api
bash scripts/run_backend_async.sh
```

Inline finalize mode (legacy path):
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/backend/vocal_coach_api
bash scripts/run_backend.sh
```

To force inline mode via one-command launcher:
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced
BACKEND_START_SCRIPT=scripts/run_backend.sh bash .script/run-all-android.sh
```

You should see startup log like:
`runtime_config ... ollama_enabled=True ollama_models=llama3:latest ollama_timeout_s=60`

### Terminal C: Launch emulator + run app
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/mobile/vocal_coach_app
flutter emulators --launch Pixel_6a
flutter run -d emulator-5554
```

## Verify AI feedback + analytics quickly

```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/backend/vocal_coach_api
python3 scripts/seed_sessions.py --base-url http://127.0.0.1:8000 --auth-token dev_seed-user --sessions 6 --metrics-per-session 3 --spread-days 6
bash scripts/check_analytics.sh
```

Expected:
- seeded session output shows `model=llama3:latest` or `model=qwen2.5:7b`
- dashboard endpoint returns non-zero `total_completed_sessions`
- trends endpoint returns daily points for selected range (`/v1/analytics/trends?range=7d`)

## Firestore mode (optional)

```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/backend/vocal_coach_api
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
export FIRESTORE_ENABLED=true
export FIRESTORE_PROJECT_ID=cockatiel-enhanced
bash scripts/run_backend.sh
```

## Test commands
- Fallback mode: `python3 -m pytest tests/unit tests/integration -q`
- Ollama mocked mode: `TEST_USE_OLLAMA=true TEST_MOCK_OLLAMA=true python3 -m pytest tests/unit tests/integration -q`
- Ollama real mode: `TEST_USE_OLLAMA=true TEST_MOCK_OLLAMA=false python3 -m pytest tests/unit tests/integration -q`

## Analytics APIs
- `GET /v1/analytics/dashboard`
- `GET /v1/analytics/trends?range=7d|30d|90d`

## AI diagnostics API
- `GET /v1/ai/health` (reports Ollama reachability + configured model availability)
- `GET /v1/ai/jobs` (lists AI evaluation jobs for current user)
- `GET /v1/ai/jobs/{jobId}` (returns job detail/status)

## Audio snippet APIs (Sprint 7)
- `POST /v1/sessions/{sessionId}/audio-snippets` (base64 payload + metadata)
- `GET /v1/sessions/{sessionId}/audio-snippets`
- `POST /v1/audio-snippets/cleanup?before_ms=<timestamp_ms>`

Sprint 5.1 cache behavior:
- On every completed session finalize, backend updates a cached daily rollup document.
- Firestore path: `analytics/{userId}/daily_rollups/{YYYY-MM-DD}`.
- Trends endpoint reads cached daily rollups (not raw sessions) for faster range queries.

Seed script options:
- `--spread-days N` distributes seeded sessions across past N days to populate trend charts.
- `--wait-timeout-s N` waits for async feedback completion when `AI_ASYNC_ENABLED=true`.

Sprint 6 async queue behavior:
- `AI_ASYNC_ENABLED=true` makes finalize return `status=processing` immediately.
- Inline worker consumes queued AI jobs and updates sessions to `completed` (or `failed` on retry exhaustion).
- Queue-related metrics are exposed in `/metrics`.
- Dev script defaults are `OLLAMA_MODELS=llama3:latest`, `OLLAMA_TIMEOUT_S=180`, and `AI_WORKER_MAX_RETRIES=5`.

Sprint 7 audio storage behavior:
- Default storage backend is local filesystem (`AUDIO_SNIPPET_STORAGE_BACKEND=local`).
- Default local path is `/tmp/vocal-coach/audio-snippets` (`AUDIO_SNIPPET_LOCAL_DIR`).
- Snippet retention defaults to 30 days (`AUDIO_SNIPPET_RETENTION_DAYS`).
- Size/duration guards: `AUDIO_SNIPPET_MAX_BYTES`, `AUDIO_SNIPPET_MAX_DURATION_SEC`.
- Metadata is linked to session/user and persisted in repository backend.
- Automatic cleanup worker is enabled by default (`AUDIO_SNIPPET_CLEANUP_WORKER_ENABLED=true`).
- Cleanup worker interval defaults to hourly (`AUDIO_SNIPPET_CLEANUP_INTERVAL_SEC=3600`).

Audio snippet example payload:
```json
{
  "audio_base64": "UklGRi4uLg==",
  "content_type": "audio/wav",
  "duration_sec": 5.2,
  "sample_rate_hz": 44100,
  "channel_count": 1,
  "recorded_at_ms": 1773733000000
}
```

## Sprint tracking
- Full sprint history, status, and per-file implementation checklist live in `Sprint.md`.

## Common troubleshooting
- `bash: scripts/run_backend.sh: No such file or directory`
  - Run it from backend folder, or use absolute path to `backend/vocal_coach_api/scripts/run_backend.sh`.
- `model_used: fallback-rules`
  - Ensure Ollama service is running and backend startup log says `ollama_enabled=True`.
- `RecaptchaAction(signUpPassword) network error`
  - Emulator cannot complete Firebase Auth anti-abuse challenge. Check emulator internet/Google Play services, or run with Firebase Auth emulator via `--dart-define=USE_FIREBASE_AUTH_EMULATOR=true`.
- Android emulator cannot reach backend localhost
  - App is already configured to use `10.0.2.2` on Android emulator.
- Disk full during Android build
  - Free disk space and rerun `flutter run`.
