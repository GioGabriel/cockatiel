# Requirements Document

## Introduction

A comprehensive visual and animation polish pass for the Cockatiel vocal coaching Flutter app targeting Android. This spec covers modern Dribbble-level UI enhancements including page transitions, micro-interactions, loading states, entrance animations, glassmorphism accents, and animated metric displays. No new features or screens are added — only visual refinement of existing screens to create a thesis-defense-ready demo with smooth, contemporary motion design.

## Glossary

- **App**: The Cockatiel vocal coaching Flutter mobile application targeting Android
- **Page_Transition_System**: The component responsible for animated transitions between screens including hero animations, shared element transitions, and slide/fade combinations
- **Micro_Interaction_System**: The component that applies subtle feedback animations to interactive elements such as buttons, cards, and toggles
- **Shimmer_Loader**: The component that displays animated placeholder skeletons while content loads, replacing static spinners
- **Entrance_Animation_Controller**: The component that orchestrates staggered fade-and-slide entrance animations for lists and card collections
- **Metric_Animator**: The component that animates numeric score displays with count-up effects, progress ring fills, and pulse accents
- **Session_Flow_Transition**: The component managing smooth visual handoffs between briefing, live session, and results screens
- **Glass_Card**: A card widget variant applying frosted glass (glassmorphism) visual treatment with backdrop blur and translucent backgrounds
- **Bottom_Sheet_Presenter**: The component that animates modal bottom sheets with spring-damped slide and fade transitions
- **Empty_State_Display**: The component that shows animated illustrations and friendly messaging when no data is available
- **Dashboard_Page**: The Home Dashboard screen showing welcome banner, progress stats, recommendations, and practice module cards
- **Auth_Page**: The authentication screens including login and registration flows
- **Training_Catalog_Page**: The screen listing available vocal training exercises
- **Training_Session_Page**: The live vocal training recording and feedback screen
- **Karaoke_Catalog_Page**: The screen listing available karaoke practice songs
- **Karaoke_Briefing_Page**: The song briefing screen before a karaoke session
- **Analytics_Page**: The screen displaying progress charts, streaks, and score trends
- **Profile_Page**: The user profile and preferences screen

## Requirements

### Requirement 1: Page Transition Animations

**User Story:** As a user, I want smooth animated transitions between screens, so that navigation feels fluid and polished rather than abrupt.

#### Acceptance Criteria

1. WHEN a user navigates from Dashboard_Page to any Practice Module page, THE Page_Transition_System SHALL apply a shared element hero animation to the module's icon container with a duration of 400–500ms using Curves.easeOutCubic
2. WHEN a user navigates forward to a detail screen (briefing, session, or results), THE Page_Transition_System SHALL apply a combined slide-from-right and fade-in transition with a duration of 400ms using Curves.easeOutCubic
3. WHEN a user navigates backward via the back button or swipe gesture, THE Page_Transition_System SHALL apply a combined slide-to-right and fade-out transition with a duration of 350ms using Curves.easeInCubic
4. WHEN a user navigates between bottom navigation tabs, THE Page_Transition_System SHALL apply a cross-fade transition with a duration of 250ms
5. WHEN a user navigates from Auth_Page to Dashboard_Page after login, THE Page_Transition_System SHALL apply a scale-up and fade-in transition with a duration of 500ms to convey a "welcome" moment

### Requirement 2: Micro-Interaction Feedback

**User Story:** As a user, I want subtle animated feedback when I interact with buttons and cards, so that the interface feels responsive and tactile.

#### Acceptance Criteria

1. WHEN a user presses a primary FilledButton, THE Micro_Interaction_System SHALL apply a scale-down to 0.96 transform with a duration of 100ms on press and scale-up to 1.0 on release with a duration of 200ms using Curves.easeOutCubic
2. WHEN a user taps a module card on Dashboard_Page, THE Micro_Interaction_System SHALL apply a scale-down to 0.97 transform with an elevation increase during the press with a duration of 150ms
3. WHEN a user taps an exercise or song list item, THE Micro_Interaction_System SHALL apply a subtle background highlight animation with a duration of 200ms
4. WHEN a toggle or switch changes state, THE Micro_Interaction_System SHALL animate the transition with a spring curve over 250ms

### Requirement 3: Shimmer Loading States

**User Story:** As a user, I want to see animated skeleton placeholders while content loads, so that the app feels responsive and never appears frozen.

#### Acceptance Criteria

1. WHILE content is loading on Dashboard_Page, THE Shimmer_Loader SHALL display shimmer-animated skeleton cards matching the layout shape of progress stats, recommendations, and module cards
2. WHILE content is loading on Training_Catalog_Page or Karaoke_Catalog_Page, THE Shimmer_Loader SHALL display shimmer-animated skeleton list items matching the height and spacing of real list items
3. WHILE content is loading on Analytics_Page, THE Shimmer_Loader SHALL display shimmer-animated skeleton rectangles matching the chart and stat card layout
4. THE Shimmer_Loader SHALL use a horizontal gradient sweep animation cycling every 1200ms with colors derived from the surface color (surface at 100% opacity transitioning through surface at 40% opacity and back)
5. WHEN content finishes loading, THE Shimmer_Loader SHALL fade out over 200ms and the real content SHALL fade in over 300ms with a staggered delay

### Requirement 4: Staggered Entrance Animations

**User Story:** As a user, I want cards and list items to animate into view with a staggered cascade effect, so that screen content feels dynamic and intentionally choreographed.

#### Acceptance Criteria

1. WHEN Dashboard_Page content loads, THE Entrance_Animation_Controller SHALL animate each card from 24px below its final position with zero opacity to its final position with full opacity, staggered by 60ms per item, using a duration of 400ms and Curves.easeOutCubic
2. WHEN Training_Catalog_Page or Karaoke_Catalog_Page content loads, THE Entrance_Animation_Controller SHALL animate each list item with the same slide-up and fade-in pattern staggered by 50ms per item
3. WHEN Analytics_Page content loads, THE Entrance_Animation_Controller SHALL animate stat cards first (staggered 80ms) then chart containers (staggered 100ms) in a top-to-bottom sequence
4. THE Entrance_Animation_Controller SHALL only trigger entrance animations on the first render of a screen, not on rebuilds caused by state changes

### Requirement 5: Animated Metric Displays

**User Story:** As a user, I want my scores and statistics to animate into their final values with counting and ring-fill effects, so that progress feels tangible and rewarding.

#### Acceptance Criteria

1. WHEN a numeric score becomes visible on Dashboard_Page or Analytics_Page, THE Metric_Animator SHALL animate the value from 0 to the final number using a count-up interpolation over 800ms with Curves.easeOutCubic
2. WHEN a circular progress indicator (streak ring, completion ring) becomes visible, THE Metric_Animator SHALL animate the fill arc from 0 to the target percentage over 1000ms with Curves.easeOutCubic
3. WHEN a training session produces a final score on the results screen, THE Metric_Animator SHALL display the score with a count-up animation followed by a single pulse scale effect (1.0 to 1.08 to 1.0) over 300ms upon reaching the final value
4. WHEN a score exceeds a personal best threshold, THE Metric_Animator SHALL apply a gold (#E1B261) glow accent pulse that fades out over 600ms

### Requirement 6: Session Flow Transitions

**User Story:** As a user, I want smooth visual handoffs between briefing, live session, and results screens, so that the training flow feels cohesive and guided.

#### Acceptance Criteria

1. WHEN a user transitions from Karaoke_Briefing_Page to the live session, THE Session_Flow_Transition SHALL apply a vertical slide-up transition with a fade overlay lasting 450ms using Curves.easeOutCubic
2. WHEN a user transitions from a live session to the results screen, THE Session_Flow_Transition SHALL apply a scale-down of the session content (to 0.92) combined with a fade-in of the results overlay lasting 500ms
3. WHEN a user transitions from exercise briefing to Training_Session_Page, THE Session_Flow_Transition SHALL apply a horizontal slide-left combined with a brief recording-indicator pulse animation
4. THE Session_Flow_Transition SHALL maintain continuity of shared elements (exercise title, song title) across the briefing-to-session-to-results sequence using Hero animations

### Requirement 7: Glassmorphism Accent Cards

**User Story:** As a user, I want select UI elements to feature frosted-glass visual effects, so that the interface has modern depth and sophistication.

#### Acceptance Criteria

1. THE Glass_Card SHALL apply a backdrop blur of 12px with a translucent white background (white at 70% opacity) and a subtle 1px white border at 30% opacity
2. WHEN used for the welcome banner on Dashboard_Page, THE Glass_Card SHALL layer over the existing teal gradient background while maintaining text readability with a minimum contrast ratio of 4.5:1
3. WHEN used for the floating score overlay during live training sessions, THE Glass_Card SHALL apply a 16px backdrop blur with a dark translucent background (black at 40% opacity) for visibility over dynamic content
4. THE Glass_Card SHALL only be applied to at most 3 accent elements per screen to avoid visual noise and maintain performance

### Requirement 8: Bottom Sheet and Modal Transitions

**User Story:** As a user, I want bottom sheets and modals to appear with smooth spring-like animations, so that overlays feel natural and weighty.

#### Acceptance Criteria

1. WHEN a bottom sheet is presented, THE Bottom_Sheet_Presenter SHALL slide the sheet upward from off-screen with a spring-damped animation (damping ratio 0.85) over 400ms
2. WHEN a bottom sheet is dismissed, THE Bottom_Sheet_Presenter SHALL slide the sheet downward with an ease-in curve over 300ms
3. WHEN a bottom sheet or modal appears, THE Bottom_Sheet_Presenter SHALL simultaneously fade in a dark scrim (black at 40% opacity) over 250ms
4. WHEN a confirmation dialog is presented, THE Bottom_Sheet_Presenter SHALL scale the dialog from 0.9 to 1.0 with a fade-in over 200ms using Curves.easeOutCubic

### Requirement 9: Empty State Animations

**User Story:** As a user, I want empty screens to display animated illustrations and friendly prompts, so that the app feels alive even when there is no data.

#### Acceptance Criteria

1. WHEN no training sessions exist for the user, THE Empty_State_Display SHALL show an animated illustration (Lottie or custom animated widget) with a looping gentle motion (float or breathe effect) lasting 2000ms per cycle
2. WHEN no analytics data is available, THE Empty_State_Display SHALL show an animated chart-building illustration with a CTA button that pulses subtly every 3000ms
3. THE Empty_State_Display SHALL render the illustration at a maximum size of 200x200 logical pixels to maintain layout consistency
4. THE Empty_State_Display SHALL include a headline text, a body description, and a primary CTA button arranged vertically with 16px spacing

### Requirement 10: Auth Flow Visual Polish

**User Story:** As a user, I want the login and registration screens to feel modern and branded, so that my first impression of the app is professional.

#### Acceptance Criteria

1. WHEN Auth_Page loads, THE App SHALL animate the Cockatiel logo with a fade-in and gentle scale-up (0.8 to 1.0) over 600ms using Curves.easeOutCubic
2. WHEN a user switches between login and registration forms, THE App SHALL cross-fade form fields with a combined slide offset of 16px over 300ms
3. WHEN a login attempt is in progress, THE App SHALL replace the button label with an inline progress indicator (20px white circular indicator) without changing button dimensions
4. WHEN login succeeds, THE App SHALL briefly display a checkmark icon within the button over 400ms before triggering the page transition to Dashboard_Page
