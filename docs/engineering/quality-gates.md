# Engineering quality gates

Cockatiel uses a risk-based quality process. A passing test suite is necessary but
does not by itself prove that authentication, user isolation, audio lifecycle, or
responsive accessibility behavior is correct.

## Before changing a contract or persisted behavior

1. Read `CONTRIBUTING.md` and the relevant architecture document.
2. Search callers and consumers of the affected route, field, status, and model.
3. Update the contract and compatibility tests first.
4. Add failure-path tests before implementation.
5. Keep migrations and external environment changes separate from the code change.

## Backend checks

Run from `backend/vocal_coach_api`:

```bash
pytest -q
python3 -m compileall -q app tests
ruff check app tests
pytest --cov=app --cov-report=term-missing
```

Backend tests must not require real Firebase, Firestore, OpenRouter, LRCLIB, or
Render credentials. Provider behavior is tested with fakes and bounded failure
scenarios. Tests must not print credentials or write to a production database.

## Flutter checks

CI and the validated local run use Flutter `3.47.2` stable. Run from
`mobile/vocal_coach_app` when the Flutter SDK is available:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test --coverage
flutter build web --release
flutter build apk --release
```

For platform-specific changes, also run the available Android production build
and a Chrome smoke test. Android Studio and an emulator are optional for the
APK build, but the Android SDK and project NDK are required. Widget tests should cover semantics, loading/error/empty
states, keyboard/focus behavior, text scaling, and responsive layouts for changed
surfaces.

## Required evidence in a handoff

Report the exact commands run, pass/fail status, coverage where available,
unavailable toolchains, and unverified external state. Never describe a build,
Render environment, Firebase project, Firestore contents, provider credential, or
song license as verified unless it was actually inspected.
