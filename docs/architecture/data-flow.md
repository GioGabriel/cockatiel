# Data Flow: Vocal Training Sessions

This document describes how audio data is processed from the user's microphone to the AI feedback engine.

## 1. Capture & Local Processing (Client)
- User starts a training or karaoke session.
- `LiveAudioAnalyzer` captures a 16-bit PCM audio stream from the microphone.
- The stream is chunked and analyzed locally with the deterministic YIN-style estimator to estimate fundamental pitch (Hz).
- Only voiced frames that pass the confidence and signal-quality gates are rendered; rejected frames create gaps in `KaraokePitchVisualizer`.
- The detected line is an estimated fundamental-frequency trace. It does not directly measure timbre, resonance, airflow, breath pressure, throat tension, vocal-fold behavior, vocal health, or overall singing quality.

## 2. Telemetry Aggregation (Client -> Server)
- The raw pitches are smoothed and compared against the target notes.
- A `CanonicalMetricFrame` is built every few seconds containing summary data (pitch accuracy, breath control, stability).
- These frames are sent to the FastAPI backend via a `POST /session/{session_id}/metrics` endpoint.

## 3. Storage & AI Evaluation (Server)
- The FastAPI backend ingests the frames and stores them in Firebase Firestore under the user's session document.
- When the user finishes the session, the app calls `POST /session/{session_id}/finalize`.
- A background worker on the backend runs the deterministic Coaching Logic Engine against aggregated metrics and may use Google AI Studio only for a bounded natural-language summary. The resulting `CoachingFeedback` object remains complete when Google AI Studio is disabled or unavailable.

## 4. Feedback Delivery (Server -> Client)
- The mobile app periodically polls for the completed feedback or retrieves it on the post-session screen.
- The user reviews their custom AI feedback and recommended exercises.
