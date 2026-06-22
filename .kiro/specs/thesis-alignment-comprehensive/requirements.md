# Requirements Document

## Introduction

This specification defines the work required to align the Cockatiel Enhanced vocal coaching platform with its thesis documentation deliverables. The system must fully implement six thesis modules (Account, Dashboard, Voice Room, Coaching/Tutorial, Karaoke, Progress Tracking) and remove out-of-scope features (Sprint 11 Diction/Pronunciation). The platform targets aspiring singers on Android, providing AI-driven real-time vocal feedback as an affordable alternative to professional coaching. The system must satisfy ISO 25010 evaluation criteria.

## Glossary

- **Cockatiel_Enhanced**: The AI-powered vocal coaching Android platform under thesis evaluation
- **Account_Module**: Subsystem handling user registration, authentication, profile management, and access tiers
- **Dashboard_Module**: Subsystem providing a unified overview of progress, upcoming sessions, recent evaluations, and navigation
- **Voice_Room**: Real-time vocal practice environment delivering instant AI feedback on pitch, tone, breath control, and vocal clarity
- **Coaching_Module**: Structured lesson and tutorial subsystem with progressive difficulty and AI-guided exercises
- **Karaoke_Module**: Song-based practice subsystem combining entertainment with real-time AI evaluation
- **Progress_Tracker**: Subsystem for performance assessments, trend visualization, and measurable improvement tracking
- **AI_Engine**: Backend orchestration layer using Ollama LLM for generating coaching feedback
- **Guest_User**: Unauthenticated user with limited access to explore the platform before registration
- **Registered_User**: Authenticated user with full access to all training modules and progress tracking
- **Premium_User**: Paid tier user with enhanced features such as extended session history, advanced analytics, and priority AI processing
- **Access_Tier**: Classification of user privilege level (Guest, Registered, Premium)
- **Session**: A single training or karaoke practice interaction containing attempts and metrics
- **Attempt**: One recorded practice pass within a session, scored individually
- **Feedback_Payload**: Structured AI response containing strengths, improvements, and next exercises
- **Training_Catalog**: Backend-driven collection of exercise categories, exercises, and difficulty levels
- **ISO_25010**: International standard for software quality evaluation covering functionality, usability, performance efficiency, security, and maintainability

## Requirements

### Requirement 1: Guest Access Tier

**User Story:** As a prospective user, I want to explore the platform without creating an account, so that I can evaluate its value before committing to registration.

#### Acceptance Criteria

1. WHEN the application launches without an authenticated session, THE Account_Module SHALL present a Guest exploration mode with access to the Dashboard_Module overview and Training_Catalog browsing up to exercise detail level (category list, exercise names, descriptions, difficulty levels, and objectives) without the ability to start a practice session
2. WHILE in Guest mode, THE Account_Module SHALL restrict access to live practice sessions, progress storage, and AI feedback features by displaying those features in a visually disabled state with a lock indicator distinguishing them from accessible features
3. WHILE in Guest mode, THE Dashboard_Module SHALL display a registration prompt explaining the benefits of creating an account
4. WHEN a Guest_User taps any restricted feature, THE Account_Module SHALL navigate the user to the registration flow with a message identifying the specific feature the user attempted to access and stating that registration is required to unlock it
5. IF the Training_Catalog fails to load while in Guest mode, THEN THE Dashboard_Module SHALL display an error state with a retry option and a message indicating that catalog content is temporarily unavailable

### Requirement 2: Premium Access Tier

**User Story:** As a registered user, I want to upgrade to Premium, so that I can access extended session history, advanced analytics, and priority AI processing.

#### Acceptance Criteria

1. THE Account_Module SHALL support three Access_Tier levels: Guest_User, Registered_User, and Premium_User
2. WHEN a Registered_User upgrades to Premium, THE Account_Module SHALL persist the tier change and grant Premium privileges within 5 seconds of the upgrade action completing
3. WHILE a user has Premium_User tier, THE Progress_Tracker SHALL retain session history for 365 days, compared to the standard 90-day retention window for Registered_User accounts
4. WHILE a user has Premium_User tier, THE AI_Engine SHALL place feedback requests ahead of non-Premium requests in the evaluation queue such that Premium requests are dequeued before any Registered_User requests submitted after them
5. WHILE a user has Premium_User tier, THE Progress_Tracker SHALL provide advanced analytics including per-metric trend breakdowns across all retained history and comparative scoring against the user's own 30-day rolling average
6. IF the tier change persistence fails during a Premium upgrade, THEN THE Account_Module SHALL retain the user's existing Registered_User tier, display an error message indicating the upgrade could not be completed, and allow the user to retry
7. IF a Premium_User tier expires or is downgraded, THEN THE Progress_Tracker SHALL retain session history accumulated during the Premium period but limit new session retention to the standard 90-day window going forward

### Requirement 3: Profile Management with Vocal Preferences

**User Story:** As a registered user, I want to manage my profile including vocal preferences, so that the system can personalize my training experience.

#### Acceptance Criteria

1. THE Account_Module SHALL provide a profile management screen displaying user name, email, vocal range classification, preferred exercise categories, and training goal
2. WHEN a user updates vocal preferences, THE Account_Module SHALL validate that vocal range is one of the six allowed classifications, preferred exercise categories are selected from the Training_Catalog categories (maximum 3), and training goal is one of: pitch improvement, breath control, tone quality, range extension, or general skill building
3. WHEN a user submits valid vocal preference updates, THE Account_Module SHALL persist the changes within 3 seconds and return the updated profile to confirm success
4. IF a user submits vocal preference updates with invalid values, THEN THE Account_Module SHALL reject the update, preserve existing preferences unchanged, and return an error message indicating which fields failed validation
5. THE Account_Module SHALL allow users to set a vocal range classification from the following options: soprano, mezzo-soprano, alto, tenor, baritone, bass
6. WHEN vocal preferences are set, THE Coaching_Module SHALL use the preferences to filter recommended exercises to those matching the user's preferred categories and prioritize exercises appropriate for the user's vocal range classification
7. IF a user has not set vocal preferences, THEN THE Coaching_Module SHALL recommend exercises using default prioritization based on historical performance data without applying preference-based filtering

### Requirement 4: Dashboard Overview

**User Story:** As a registered user, I want a comprehensive dashboard showing my progress overview, upcoming sessions, and recent evaluations, so that I can quickly understand my training status and navigate to relevant features.

#### Acceptance Criteria

1. THE Dashboard_Module SHALL display a progress summary including total completed sessions, current practice streak, and average score for the last 7 days
2. THE Dashboard_Module SHALL display the three most recent session evaluations with exercise name, score, and completion timestamp
3. THE Dashboard_Module SHALL provide quick-access navigation cards to all thesis modules: Vocal Coach, Karaoke Practice, Analytics, and Profile
4. WHEN the Dashboard_Module loads, THE Dashboard_Module SHALL fetch fresh analytics data from the backend within 3 seconds on a stable network connection
5. THE Dashboard_Module SHALL display personalized training recommendations based on the user's progress and weak areas

### Requirement 5: Voice Room Real-Time Practice

**User Story:** As a registered user, I want a controlled practice environment that provides real-time AI feedback on my vocal performance, so that I can improve through immediate corrective guidance.

#### Acceptance Criteria

1. WHEN a user starts a Voice_Room session, THE Voice_Room SHALL activate microphone input and begin real-time audio analysis
2. WHILE a session is active, THE Voice_Room SHALL display live metrics including pitch accuracy, breath control status, and vocal clarity indicators
3. WHEN an attempt is completed, THE Voice_Room SHALL submit metric summaries to the AI_Engine for coaching feedback generation
4. THE Voice_Room SHALL provide a safe practice environment by allowing users to retry up to the configured maximum attempts per session
5. WHEN AI feedback is generated, THE Voice_Room SHALL display structured coaching feedback with strengths, areas for improvement, and recommended next exercises
6. THE Voice_Room SHALL support both synchronous and asynchronous feedback modes, displaying a processing indicator when feedback generation is queued

### Requirement 6: Coaching Module Structured Lessons

**User Story:** As a registered user, I want structured lessons covering breath control, pitch correction, tone quality, and articulation, so that I can systematically develop my vocal skills through guided exercises.

#### Acceptance Criteria

1. THE Coaching_Module SHALL provide a training catalog organized into categories: Vocal Training, Do Re Mi Pitch, and Breathing Exercises
2. WHEN a user selects an exercise category, THE Coaching_Module SHALL display available exercises with name, description, objective, difficulty level, and microphone requirements
3. THE Coaching_Module SHALL support three difficulty levels (beginner, intermediate, advanced) with progressive complexity within each exercise
4. WHEN a user starts an exercise, THE Coaching_Module SHALL display a briefing screen explaining the exercise objective, instructions, and what the user will do
5. WHILE an exercise is active, THE Coaching_Module SHALL render animated guided steps with countdown timers and haptic feedback cues
6. THE Coaching_Module SHALL tailor exercise recommendations to the user's current skill level based on historical performance data
7. WHEN a user completes a session, THE AI_Engine SHALL generate feedback that references the specific exercise context, difficulty, and metrics achieved

### Requirement 7: Karaoke Module Song-Based Practice

**User Story:** As a registered user, I want to practice singing along with songs and receive real-time AI evaluation, so that I can improve pitch accuracy, timing, and expression in an entertaining context.

#### Acceptance Criteria

1. THE Karaoke_Module SHALL provide a song selection interface with available karaoke drills categorized by style, displaying at least 1 drill per category
2. WHEN a user selects a karaoke drill, THE Karaoke_Module SHALL create a session with mode "karaoke" and begin the live practice flow
3. WHILE a karaoke session is active, THE Karaoke_Module SHALL capture vocal input and measure pitch accuracy, timing accuracy, and breath control using the system's canonical voice metric schema with each metric scored from 0 to 100
4. WHEN a karaoke session is finalized, THE AI_Engine SHALL generate feedback containing an overall score from 0 to 100, up to 3 strengths, up to 3 improvements, and up to 2 recommended next exercises covering pitch accuracy, timing, and breath control
5. WHILE a karaoke session is active, THE Karaoke_Module SHALL display visual indicators updated at least every 100 milliseconds showing the user's detected pitch relative to the expected melody line
6. THE Karaoke_Module SHALL provide a song catalog with metadata including song title, artist reference, difficulty level (beginner, intermediate, or advanced), tempo in BPM, and vocal range expressed as lowest and highest note
7. IF the AI_Engine fails to generate feedback after finalization, THEN THE Karaoke_Module SHALL display an error indication to the user, preserve the session metrics, and mark the session status as "failed" with a failure reason
8. IF microphone access is unavailable when starting a karaoke session, THEN THE Karaoke_Module SHALL display an error indication explaining that microphone permission is required and SHALL NOT create the session

### Requirement 8: Progress Tracking and Analytics

**User Story:** As a registered user, I want to view my performance assessments over time with measurable improvements and trend charts, so that I can stay motivated and track skill development.

#### Acceptance Criteria

1. THE Progress_Tracker SHALL display an analytics dashboard with session counts, average scores, and streak data across 7-day, 30-day, and 90-day time ranges
2. THE Progress_Tracker SHALL render trend charts showing daily average scores and per-metric breakdowns over the selected time range
3. THE Progress_Tracker SHALL display per-exercise progress including sessions completed, average score, best score, last score, and last completion date
4. WHEN new session data is available, THE Progress_Tracker SHALL update cached daily rollups to maintain responsive trend queries
5. THE Progress_Tracker SHALL provide exercise-specific recommendations identifying weak areas and suggesting targeted practice

### Requirement 9: Sprint 11 Scope Removal

**User Story:** As a thesis evaluator, I want the system to contain only modules documented in the thesis, so that the defense demonstration reflects the documented scope without undocumented features.

#### Acceptance Criteria

1. THE Cockatiel_Enhanced system SHALL NOT include diction, pronunciation, or phrase clarity training features in the evaluated build
2. THE Cockatiel_Enhanced system SHALL NOT include transcription-based text alignment or Whisper integration in the evaluated build
3. WHEN building the thesis evaluation release, THE build process SHALL exclude Sprint 11 planned features from compilation and runtime
4. THE Training_Catalog SHALL contain only exercises within thesis-documented categories: Vocal Training, Do Re Mi Pitch, and Breathing Exercises

### Requirement 10: ISO 25010 Compliance Support

**User Story:** As a thesis evaluator, I want the system to demonstrate compliance with ISO 25010 quality attributes, so that the platform can be evaluated against established software quality standards.

#### Acceptance Criteria

1. THE Cockatiel_Enhanced system SHALL provide complete functional coverage for all six thesis modules (Account, Dashboard, Voice Room, Coaching, Karaoke, Progress Tracking)
2. THE Cockatiel_Enhanced system SHALL respond to user interactions within 3 seconds for standard operations and 10 seconds for AI feedback generation on a stable network
3. THE Cockatiel_Enhanced system SHALL validate all user input at the API boundary and reject malformed requests with descriptive error messages
4. THE Cockatiel_Enhanced system SHALL authenticate all API requests using Firebase Auth tokens, preventing unauthorized access to user data
5. THE Cockatiel_Enhanced system SHALL maintain modular code architecture with clear separation between API layer, service layer, and data layer for maintainability
6. THE Cockatiel_Enhanced system SHALL provide clear, consistent navigation patterns and loading states following Material Design guidelines for usability

### Requirement 11: Android Platform Target

**User Story:** As a thesis evaluator, I want the system to run exclusively on Android, so that the evaluation matches the documented target platform.

#### Acceptance Criteria

1. THE Cockatiel_Enhanced mobile application SHALL build and run on Android devices running API level 21 (Android 5.0) or higher
2. THE Cockatiel_Enhanced mobile application SHALL use the Android emulator (Pixel 6a configuration) as the primary development and testing target
3. THE Cockatiel_Enhanced system SHALL NOT require iOS or web platform builds for thesis evaluation
4. THE mobile application SHALL access device microphone through Android-native permission APIs for real-time audio capture

### Requirement 12: AI Feedback Engine Verification

**User Story:** As a thesis evaluator, I want to verify that the AI provides meaningful coaching feedback on pitch, tone, rhythm, breath control, and vocal clarity, so that the system demonstrates its core value proposition.

#### Acceptance Criteria

1. WHEN a session is finalized with valid metrics, THE AI_Engine SHALL generate a Feedback_Payload containing overall score, strengths list, improvements list, and next exercise recommendations
2. THE AI_Engine SHALL evaluate vocal performance across five dimensions: pitch accuracy, timing accuracy, breath control, pitch stability, and note transition smoothness
3. IF the AI model is unreachable or times out, THEN THE AI_Engine SHALL fall back to deterministic rule-based scoring and indicate the fallback in the response
4. THE AI_Engine SHALL include the model identifier and prompt version in every Feedback_Payload for traceability
5. WHEN processing training sessions with multiple attempts, THE AI_Engine SHALL evaluate based on the best attempt metrics and improvement trajectory

### Requirement 13: Karaoke Song Catalog Enrichment

**User Story:** As a registered user, I want a browsable catalog of karaoke songs with clear metadata, so that I can choose songs appropriate for my skill level and vocal range.

#### Acceptance Criteria

1. THE Karaoke_Module SHALL provide a minimum of three karaoke drill categories, each representing a distinct musical style or vocal focus area, where no two categories share the same style label
2. WHEN displaying the song catalog, THE Karaoke_Module SHALL show for each entry: song title, style category, difficulty level (one of beginner, intermediate, or advanced), and estimated duration in seconds (ranging from 30 to 180)
3. THE Karaoke_Module SHALL retrieve the song catalog from the backend on each catalog screen visit, allowing catalog content changes without requiring a mobile application update
4. WHEN a user selects a song, THE Karaoke_Module SHALL display a briefing screen showing: the song title, style category, difficulty level, estimated duration, a textual objective description, and at least one performance tip relevant to the song's focus area
5. IF the catalog request to the backend fails or returns an empty catalog, THEN THE Karaoke_Module SHALL display an error state with a message indicating the catalog is unavailable and a retry action that re-requests the catalog
