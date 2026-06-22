# Mobile UI/UX Best Practices

Design and interaction standards for the Vocal Coach Flutter mobile app.

## Design Principles

1. **Clarity over decoration** — Every element earns its place. Remove anything that doesn't help the user complete their task.
2. **Progressive disclosure** — Show essentials first, reveal complexity on demand. The exercise briefing → session → results flow embodies this.
3. **Forgiving interaction** — Allow retries (training attempts), undo (back navigation), and clear error recovery paths.
4. **Performance as UX** — A loading spinner that never appears is the best animation. Prefetch and cache aggressively.

## Layout Standards

### Spacing System (8px grid)

- Tight: 4px (within grouped elements)
- Base: 8px (icon-to-label, inline padding)
- Standard: 16px (section padding, card content)
- Comfortable: 24px (between cards, section gaps)
- Spacious: 32px (page-level vertical rhythm)
- Page padding: horizontal 20px, top 16px

### Touch Targets

- Minimum: 48x48px (Material accessibility guideline).
- Preferred: 54px height for primary buttons (matches `FilledButton` theme).
- Spacing between tappable elements: minimum 8px.

### Cards

- Use the themed `Card` (24px radius, white, subtle outline).
- Content padding: 16–20px.
- For list items inside cards, use `ListTile` or custom row with 16px internal padding.
- Avoid stacking cards with no spacing — use 12–16px vertical gap.

## Navigation Patterns

- Use bottom navigation for top-level sections (Home, Training, Analytics, Profile).
- Use push navigation for drill-down flows (category → exercise → briefing → session → results).
- Back button always works. No dead-end screens.
- Use `Navigator.pushReplacement` after auth to prevent returning to login.

## Feedback & Loading States

### Loading

- Skeleton/shimmer for content areas (not spinners) on first load.
- Inline `CircularProgressIndicator` (small, 20px) for button actions.
- Never block the entire screen for a non-blocking operation.

### Empty States

- Provide a friendly message + illustration/icon + CTA when there's no data.
- Example: "No sessions yet. Start your first vocal training!" + button.

### Error States

- Inline error messages (red text below the failed element), not snackbars for form errors.
- Use `SnackBar` only for transient, non-critical notifications.
- Retry button for network errors. Never show raw error codes to users.

### Success States

- Brief confirmation (checkmark animation or green accent) then auto-advance.
- Don't keep users on a "success" screen longer than 1.5 seconds.

## Animation & Motion

- Use `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher` for state transitions.
- Duration: 200–300ms for micro-interactions, 400–500ms for page transitions.
- Curves: `Curves.easeOutCubic` for enters, `Curves.easeInCubic` for exits.
- Haptic feedback (`HapticFeedback.lightImpact()`) on countdown ticks and session milestones only. Don't over-haptic.

## Typography Hierarchy (in-page)

- Page title: `headlineSmall` (Sora Bold).
- Section title: `titleMedium` (Sora SemiBold).
- Card title: `titleSmall` (Sora SemiBold).
- Body: `bodyMedium` (Manrope Regular).
- Caption/label: `bodySmall` or `labelMedium` (Manrope).
- Metric values: `headlineMedium` or `titleLarge` (Sora Bold) with primary color.

## Color Usage

- Primary (teal `#0E7C86`): CTAs, active states, progress indicators, key metrics.
- Secondary (gold `#E1B261`): Highlights, badges, achievements, warnings.
- Error: `colorScheme.error` — never hardcode red.
- Surface: white cards on `#F4F7FB` background.
- On-surface: default text. Use `colorScheme.onSurfaceVariant` for secondary text.

## Accessibility

- All images and icons have semantic labels.
- Form fields have associated labels (not just hint text).
- Color is never the sole indicator of state — pair with icons or text.
- Minimum contrast ratio: 4.5:1 for body text, 3:1 for large text.
- Test with TalkBack/VoiceOver periodically.

## Audio/Training-Specific UX

### Session Flow

```
Briefing (what you'll do) → Calibration (if mic) → Live Session → Review → Finalize → Results
```

- Always explain what's about to happen before starting.
- Show real-time feedback during sessions (pitch indicator, countdown, progress).
- Allow graceful exit at any point (confirm dialog if mid-session).

### Mic Permission

- Request at the moment of need (when user taps "Start"), not at app launch.
- If denied: show inline explanation + button to open settings. Never crash.

### Training Attempts

- Show attempt count clearly (e.g., "Attempt 2 of 3").
- Highlight the best attempt with a badge or gold accent.
- Allow "Try Again" until max attempts reached, then show final summary.

### AI Feedback Display

- Show feedback as cards with clear sections: Strengths (green accent), Improvements (amber), Next Steps (teal).
- If AI is still processing: show progress state with "Analyzing your session..." message + poll indicator.
- When complete: push notification + badge on the relevant tab.
