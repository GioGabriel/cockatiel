# Setup Guide

Quick reference for running the Cockatiel Vocal Coach project locally and deploying for demos.

bash .script/run-all-android.sh

---

## Prerequisites

- **Flutter** (>=3.3.0) with Dart (>=3.3.0)
- **Python** 3.11+
- **Android SDK** with at least one emulator configured
- **Git**

---

## 1. Backend (FastAPI)

### Install dependencies

```bash
cd backend/vocal_coach_api
pip install -e ".[dev]"
```

### Configure environment

Create a `.env` file at `backend/vocal_coach_api/.env`:

```
OPENROUTER_ENABLED=true
OPENROUTER_API_KEY=your-openrouter-api-key
OPENROUTER_MODEL=google/gemma-4-31b-it:free
```

Load it before starting:

```bash
export $(cat .env | xargs)
```

### Start the server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Verify

```bash
curl http://localhost:8000/health
# Expected: {"status":"ok","env":"dev"}
```

### Key defaults

| Setting | Default | Notes |
|---------|---------|-------|
| `AUTH_BYPASS` | `true` | Accepts dev tokens without Firebase verification |
| `OLLAMA_ENABLED` | `false` | Set to `true` if running local Ollama |
| `OPENROUTER_ENABLED` | `false` | Set to `true` to use OpenRouter cloud AI |

---

## 2. Mobile App (Flutter)

### Install dependencies

```bash
cd mobile/vocal_coach_app
flutter pub get
```

### Run on emulator (local backend)

Make sure the backend is running on port 8000, then:

```bash
flutter run
```

The app defaults to `http://10.0.2.2:8000` which maps to your laptop's localhost from the Android emulator.

### Run on emulator (Render cloud backend)

No local backend needed:

```bash
flutter run --dart-define=API_BASE_URL=https://cockatiel-wdkv.onrender.com
```

### Build APK for a real phone

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://cockatiel-wdkv.onrender.com
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`

Install on a connected phone:

```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Available dart-define flags

| Flag | Default | Description |
|------|---------|-------------|
| `API_BASE_URL` | (auto by platform) | Override backend URL |
| `USE_DEV_AUTH_TOKEN` | `true` | Send `dev_{uid}` tokens (for AUTH_BYPASS backend) |
| `USE_FIREBASE_AUTH_EMULATOR` | `false` | Connect to Firebase Auth emulator |

---

## 3. Emulators

### List available emulators

```bash
emulator -list-avds
```

### Launch an emulator

```bash
emulator @Medium_Phone_API_36.0
# or
emulator @Pixel_6a
```

### Check device is ready

```bash
adb devices
# Should show: emulator-5554   device
```

---

## 4. Common Scenarios

### Local development (full stack)

```bash
# Terminal 1: Backend
cd backend/vocal_coach_api
export $(cat .env | xargs)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2: Emulator
emulator @Medium_Phone_API_36.0

# Terminal 3: Flutter app
cd mobile/vocal_coach_app
flutter run
```

### Client demo (standalone phone)

1. Ensure Render is deployed at https://cockatiel-wdkv.onrender.com
2. Build APK:
   ```bash
   cd mobile/vocal_coach_app
   flutter build apk --debug --dart-define=API_BASE_URL=https://cockatiel-wdkv.onrender.com
   ```
3. Transfer APK to phone and install

### Same-WiFi demo (phone + laptop)

1. Find your laptop IP: `ipconfig getifaddr en0`
2. Start backend: `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`
3. Build APK with your IP:
   ```bash
   flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.x.x:8000
   ```

---

## 5. Running Tests

### Backend

```bash
cd backend/vocal_coach_api
python3 -m pytest tests/unit tests/integration -q
```

### Mobile

```bash
cd mobile/vocal_coach_app
dart analyze
flutter build apk --debug
```

---

## 6. Deployment (Render)

The backend is deployed at: **https://cockatiel-wdkv.onrender.com**

To redeploy after code changes:

```bash
git add -A && git commit -m "your message" && git push
```

Render auto-deploys from the `main` branch.

### Render environment variables

| Key | Value |
|-----|-------|
| `AUTH_BYPASS` | `true` |
| `OPENROUTER_ENABLED` | `true` |
| `OPENROUTER_API_KEY` | (your key) |
| `OPENROUTER_MODEL` | `google/gemma-4-31b-it:free` |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Port 8000 already in use | `lsof -ti:8000 \| xargs kill -9` |
| "Failed to load profile from backend" | Backend not running, or wrong URL |
| "Address already in use" on emulator | Close existing emulator instance |
| Render cold start slow (30-50s) | First request wakes up free tier; subsequent requests are fast |
| Firebase auth works but profile fails | Ensure `USE_DEV_AUTH_TOKEN=true` matches backend `AUTH_BYPASS=true` |
