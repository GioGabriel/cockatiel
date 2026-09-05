# Vocal Coach Flutter App

This is the Flutter client for the Vocal Coach project.

For full setup and backend instructions, see the repo root guide:
- `../../README.md`

Quick run (Chrome, no emulator required):

1) Start the backend in another terminal:
```bash
cd /Users/giogabrielsanchez/Documents/ChatGPT/ccktiel/cockatiel/backend/vocal_coach_api
bash scripts/run_backend.sh
```

2) From this folder, run the browser client:
```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android Studio and an emulator are not required to build the release APK, but
the Android SDK, build-tools, platform-tools, and the project NDK must be
installed and exposed through `ANDROID_SDK_ROOT`. Use a physical Android device
for microphone/audio verification when available.

Auth notes:
- App now uses Firebase email/password auth (signup/login/forgot-password).
- The client always uses Firebase ID tokens. For a local synthetic backend identity,
  start the backend explicitly with `AUTH_BYPASS=true`; this is never enabled by
  the mobile release build.

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
