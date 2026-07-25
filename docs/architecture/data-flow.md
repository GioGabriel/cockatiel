# Data Flow: Vocal Training Sessions

This document describes how audio data is processed from the user's microphone to the AI feedback engine.

## 1. Capture & Local Processing (Client)
- User starts a training or karaoke session.
- `LiveAudioAnalyzer` captures a 16-bit PCM audio stream from the microphone.
- The stream is chunked and analyzed locally using Autocorrelation to determine the pitch (Hz).
- The detected pitch is visually rendered on the screen (the orange line in `KaraokePitchVisualizer`).

## 2. Telemetry Aggregation (Client -> Server)
- The raw pitches are smoothed and compared against the target notes.
- A `CanonicalMetricFrame` is built every few seconds containing summary data (pitch accuracy, breath control, stability).
- These frames are sent to the FastAPI backend via a `POST /session/{session_id}/metrics` endpoint.

## 3. Storage & AI Evaluation (Server)
- The FastAPI backend ingests the frames and stores them in Firebase Firestore under the user's session document.
- When the user finishes the session, the app calls `POST /session/{session_id}/finalize`.
- A background worker on the backend uses OpenRouter (e.g., Claude/Gemini) to evaluate the aggregated metrics and generate a `CoachingFeedback` object (strengths, improvements, next exercises).

## 4. Feedback Delivery (Server -> Client)
- The mobile app periodically polls for the completed feedback or retrieves it on the post-session screen.
- The user reviews their custom AI feedback and recommended exercises.
