# Vocal Coach (Cockatiel Enhanced)

AI-powered vocal coaching platform with a Flutter mobile app, a FastAPI backend (hosted on Render), and Firebase for auth/database.

## Features
- **Neon Dark Mode UI:** Premium, glassmorphic design optimized for mobile.
- **Vocal Exercises:** Pitch matching, solfege practice, and scale training with real-time feedback.
- **Karaoke Practice:** Sing along to catalog songs with Yousician-style scrolling pitch visualizer.
- **Real-time Audio Analysis:** High-performance PCM streaming and autocorrelation pitch detection.
- **AI Feedback:** Detailed coaching and recommendations generated dynamically.
- **Access Tiers:** Guest, Registered, and Premium user tiers.

## Project Structure
- `mobile/vocal_coach_app/` - The Flutter mobile application.
- `backend/vocal_coach_api/` - The Python FastAPI backend for AI and heavy data processing.
- `contracts/` - Shared schemas and API definitions.
- `docs/` - Architecture, product requirements, and historical sprint notes.

## Setup Instructions

### 1. Backend Setup
The backend is currently deployed on Render (`https://cockatiel-wdkv.onrender.com`). If you need to run it locally:
```powershell
cd backend\vocal_coach_api
python -m venv .venv
.\.venv\Scripts\Activate
pip install -e ".[dev,firestore]"
uvicorn app.main:app --reload --port 8000
```
*(Make sure you have your `.env` configured with your Google Cloud credentials and OpenRouter keys if running locally).*

### 2. Mobile App Setup
```powershell
cd mobile\vocal_coach_app
flutter pub get
flutter run
```

### 3. Running Tests
We have a robust suite of tests (nearly 100 tests) covering the core domain models, state management, and reusable widgets.
```powershell
cd mobile\vocal_coach_app
flutter test
```

*Note: The project uses a pre-commit hook that runs `flutter analyze` and blocks commits if there are warnings or errors. Ensure your code is clean before committing!*
