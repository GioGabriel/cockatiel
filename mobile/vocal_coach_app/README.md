# Vocal Coach Flutter App

This is the Flutter client for the Vocal Coach project.

For full setup and backend instructions, see the repo root guide:
- `../../README.md`

Quick run (Android emulator):

One command from repo root:
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced
bash .script/run-all-android.sh
```

1) Start backend in another terminal:
```bash
cd /Users/giogabrielsanchez/cockatiel-enhanced/backend/vocal_coach_api
bash scripts/run_backend.sh
```

2) From this folder, run app:
```bash
flutter emulators --launch Pixel_6a
flutter run -d emulator-5554
```

Auth notes:
- App now uses Firebase email/password auth (signup/login/forgot-password).
- Default local token mode is dev-compatible (`USE_DEV_AUTH_TOKEN=true`) so backend `AUTH_BYPASS=true` works out of the box.
- For strict backend token verification mode, run:
```bash
flutter run -d emulator-5554 --dart-define=USE_DEV_AUTH_TOKEN=false
```

Optional Firebase Auth emulator mode:
```bash
flutter run -d emulator-5554 --dart-define=USE_FIREBASE_AUTH_EMULATOR=true
```

Optional auth emulator host/port overrides:
```bash
flutter run -d emulator-5554 --dart-define=USE_FIREBASE_AUTH_EMULATOR=true --dart-define=FIREBASE_AUTH_EMULATOR_HOST=10.0.2.2 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099
```

AI queue UX notes:
- Finalize is non-blocking in async mode and pushes analysis into queue.
- The app surfaces queue status via Home top-bar AI queue icon.
- Android system notifications are always enabled for analysis completion/failure and tap-through to feedback.

Live vocal coach notes:
- Training session screen now uses real microphone input for live pitch/loudness guidance.
- Grant microphone permission when prompted (`RECORD_AUDIO`).
- "Upload Metric Sample" uses recent live mic frames instead of synthetic values.
