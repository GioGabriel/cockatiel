# System Overview

This document outlines the high-level architecture of the Vocal Coach (Cockatiel) system.

## 1. Mobile Application (Frontend)
- **Framework:** Flutter (Dart)
- **State Management:** Dependency injection via ServiceLocator (`app_state.dart`).
- **UI Architecture:** Feature-driven architecture (layered by `presentation`, `domain`, `data`).
- **Key Capabilities:**
  - Real-time PCM audio streaming from the device microphone.
  - Client-side pitch detection (Autocorrelation algorithms).
  - Custom painters for UI rendering (e.g., scrolling karaoke visualizers).

## 2. API Backend
- **Framework:** FastAPI (Python 3.14)
- **Deployment:** Render (`https://cockatiel-wdkv.onrender.com`)
- **Key Capabilities:**
  - AI Orchestration using `langchain` and OpenRouter models (e.g., Claude, Gemini).
  - Aggregating vocal session metrics.
  - Generating detailed AI coaching feedback asynchronously.

## 3. Cloud Services
- **Firebase Auth:** Handles user authentication.
- **Cloud Firestore:** Serves as the primary database for user profiles, session telemetry, and training histories.
