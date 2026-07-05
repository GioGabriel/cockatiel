# Implementation Plan: Modern UI Polish

## Overview

A visual/animation polish pass across the Cockatiel Flutter app. All work is mobile-only (no backend changes). New reusable animation primitives and widgets are created in `lib/shared/animations/` and `lib/shared/widgets/`, then integrated into existing feature screens via composition. Dependencies added: `shimmer: ^3.0.0` and `lottie: ^3.1.0`.

## Tasks

- [x] 1. Project setup and dependencies
  - [x] 1.1 Add shimmer and lottie dependencies to pubspec.yaml
    - Add `shimmer: ^3.0.0` and `lottie: ^3.1.0` to the dependencies section of `mobile/vocal_coach_app/pubspec.yaml`
    - Run `flutter pub get` to resolve
    - _Requirements: 3.4, 9.1_

  - [x] 1.2 Create shared animations directory structure
    - Create `lib/shared/animations/` directory with the following empty files: `page_transitions.dart`, `entrance_animation.dart`, `metric_animator.dart`, `micro_interaction.dart`, `spring_curves.dart`
    - _Requirements: 1.1, 2.1, 4.1, 5.1_

- [x] 2. Build animation primitives
  - [x] 2.1 Implement spring curves (`lib/shared/animations/spring_curves.dart`)
    - Create the `SpringCurve` class extending `Curve` with configurable `damping` (default 0.85) and `stiffness` (default 200.0)
    - Implement `transformInternal(double t)` using spring simulation math
    - Export a `kDefaultSpringCurve` constant for reuse
    - _Requirements: 8.1_

  - [x] 2.2 Implement page transition factories (`lib/shared/animations/page_transitions.dart`)
    - Implement `slideForwardRoute<T>()` — slide-right + fade-in, 400ms, `Curves.easeOutCubic`
    - Implement `slideBackRoute<T>()` — slide-left + fade-out, 350ms, `Curves.easeInCubic`
    - Implement `crossFadeRoute<T>()` — cross-fade, 250ms
    - Implement `scaleWelcomeRoute<T>()` — scale-up + fade, 500ms
    - Implement `slideUpRoute<T>()` — vertical slide-up + fade, 450ms
    - Implement `resultRevealRoute<T>()` — scale-down existing + fade-in overlay, 500ms
    - All factories return `PageRouteBuilder<T>` with `WidgetBuilder` and optional duration override
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.1, 6.2_

  - [x] 2.3 Implement micro-interaction wrapper (`lib/shared/animations/micro_interaction.dart`)
    - Create `Pressable` StatefulWidget with configurable `scaleDown` (default 0.96), `pressDuration` (100ms), `releaseDuration` (200ms)
    - Use `GestureDetector` with `onTapDown`/`onTapUp`/`onTapCancel` driving `ScaleTransition`
    - Create `PressableCard` variant that also increases elevation during press (scale 0.97)
    - Dispose `AnimationController` in `dispose()`
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Checkpoint - Verify animation primitives compile
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Build reusable animation widgets
  - [x] 4.1 Implement staggered entrance animation (`lib/shared/animations/entrance_animation.dart`)
    - Create `StaggeredEntrance` StatefulWidget with configurable `staggerDelay` (60ms), `itemDuration` (400ms), `slideOffset` (24.0), `curve` (easeOutCubic)
    - Use a single `AnimationController` with staggered `Interval`s per child
    - Wrap each child in `FadeTransition` + `SlideTransition`
    - Track first-render state to skip re-animation on rebuilds (use internal flag, not static Set)
    - Cap stagger to first 10 items for long lists; remaining appear instantly
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 4.2 Implement metric animator widgets (`lib/shared/animations/metric_animator.dart`)
    - Create `CountUpText` StatefulWidget — animates numeric value from 0 to target over 800ms with `Curves.easeOutCubic`, configurable `suffix`, `decimalPlaces`, `TextStyle`
    - Create `AnimatedProgressRing` StatefulWidget — animates arc fill from 0 to `progress` (0.0–1.0) over 1000ms, configurable `strokeWidth`, `size`, `color`
    - Both widgets use `SingleTickerProviderStateMixin` and dispose controllers properly
    - _Requirements: 5.1, 5.2_

  - [x] 4.3 Implement shimmer skeleton widget (`lib/shared/widgets/shimmer_skeleton.dart`)
    - Create `ShimmerSkeleton` StatelessWidget wrapping the `shimmer` package with configurable `baseColor`, `highlightColor`, `period` (1200ms)
    - Default colors derived from `theme.colorScheme.surface` (100% → 40% opacity sweep)
    - Create `SkeletonShapes` class with static factory methods: `dashboardCard()`, `listItem()`, `chartBlock()`, `statRow()` — each returns sized/shaped containers matching real layouts
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 4.4 Implement glass card widget (`lib/shared/widgets/glass_card.dart`)
    - Create `GlassCard` StatelessWidget using `ClipRRect` + `BackdropFilter` with `ImageFilter.blur`
    - Default: `blurSigma: 12`, `fillColor: Colors.white.withOpacity(0.7)`, `borderRadius: 24`, `borderOpacity: 0.3`
    - Dark variant constructor for session overlays: `GlassCard.dark()` with `blurSigma: 16`, `fillColor: Colors.black.withOpacity(0.4)`
    - Add `GlassCard.disabled()` constructor that renders a flat opaque card (performance fallback)
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 4.5 Implement animated score display (`lib/shared/widgets/animated_score_display.dart`)
    - Create `AnimatedScoreDisplay` StatefulWidget chaining count-up (800ms) then pulse (1.0→1.08→1.0, 300ms)
    - When `isPersonalBest: true`, apply gold `#E1B261` glow `BoxShadow` that fades out over 600ms
    - Use `TickerProviderStateMixin` for multiple controllers; dispose all in `dispose()`
    - _Requirements: 5.3, 5.4_

  - [x] 4.6 Implement empty state view (`lib/shared/widgets/empty_state_view.dart`)
    - Create `EmptyStateView` StatelessWidget with `headline`, `body`, optional `lottieAsset`, optional `ctaLabel`/`onCtaTap`
    - Render Lottie animation via `Lottie.asset()` at max 200×200 logical pixels with `repeat: true`
    - Fallback to static `Icon` when Lottie asset fails (via `errorBuilder`)
    - CTA button pulses (scale 1.0→1.04→1.0) every 3000ms using internal `AnimationController`
    - Vertical layout with 16px spacing between illustration, headline, body, CTA
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 4.7 Implement animated bottom sheet (`lib/shared/widgets/animated_bottom_sheet.dart`)
    - Create `showAnimatedBottomSheet<T>()` function using `showModalBottomSheet` with custom `AnimationController` and `SpringSimulation` (damping 0.85, 400ms)
    - Dismiss animation: slide-down with ease-in over 300ms
    - Scrim fades in (black at 40% opacity) over 250ms concurrently
    - Create `showAnimatedDialog<T>()` — scale 0.9→1.0 + fade-in over 200ms with `Curves.easeOutCubic`
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 5. Checkpoint - Verify all shared widgets compile
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Integrate animations into feature screens
  - [x] 6.1 Integrate into Dashboard page (`lib/features/home_dashboard/presentation/`)
    - Wrap module cards with `Pressable` (scale 0.97 on tap)
    - Wrap card list in `StaggeredEntrance` (60ms stagger)
    - Replace loading spinners with `ShimmerSkeleton` using `SkeletonShapes.dashboardCard()`
    - Add `GlassCard` to welcome banner over the teal gradient background
    - Wrap numeric stats with `CountUpText` and streak rings with `AnimatedProgressRing`
    - Use `AnimatedSwitcher` (200ms) for shimmer→content transition
    - Replace `MaterialPageRoute` calls to practice modules with `slideForwardRoute()` wrapping icons in `Hero` widgets
    - _Requirements: 1.1, 2.2, 3.1, 3.5, 4.1, 5.1, 5.2, 7.2_

  - [x] 6.2 Integrate into Auth pages (`lib/features/authentication/presentation/`)
    - Add logo entrance animation: fade-in + scale 0.8→1.0 over 600ms on page load
    - Add cross-fade with 16px slide offset (300ms) when switching between login/registration forms
    - Replace button text with inline 20px `CircularProgressIndicator` during login attempt (no dimension change)
    - Show checkmark icon in button for 400ms on success before navigating
    - Replace navigation to dashboard with `scaleWelcomeRoute()` (500ms scale-up + fade)
    - _Requirements: 1.5, 10.1, 10.2, 10.3, 10.4_

  - [x] 6.3 Integrate into Training screens (`lib/features/vocal_training/presentation/`)
    - Wrap catalog list items in `StaggeredEntrance` (50ms stagger) and `Pressable` for tap feedback
    - Replace catalog loading state with `ShimmerSkeleton` using `SkeletonShapes.listItem()`
    - Replace navigation from briefing to session with `slideUpRoute()` (vertical slide-up, 450ms)
    - Add `Hero` animation on exercise title across briefing→session→results
    - Replace navigation to results with `resultRevealRoute()` (scale-down + fade-in, 500ms)
    - Add `AnimatedScoreDisplay` to training results screen
    - Add `GlassCard.dark()` for floating score overlay during live session
    - _Requirements: 1.2, 1.3, 2.3, 3.2, 4.2, 5.3, 6.3, 6.4, 7.3_

  - [x] 6.4 Integrate into Karaoke screens (`lib/features/karaoke_practice/presentation/`)
    - Wrap song catalog list in `StaggeredEntrance` (50ms stagger) with `Pressable` on items
    - Replace catalog loading with `ShimmerSkeleton` using `SkeletonShapes.listItem()`
    - Replace briefing→session navigation with `slideUpRoute()` (450ms)
    - Add `Hero` on song title across briefing→session→results
    - Replace session→results navigation with `resultRevealRoute()` (500ms)
    - Add `AnimatedScoreDisplay` to karaoke results
    - _Requirements: 1.2, 2.3, 3.2, 4.2, 6.1, 6.2, 6.4_

  - [x] 6.5 Integrate into Analytics screen (`lib/features/analytics_dashboard/presentation/`)
    - Wrap stat cards in `StaggeredEntrance` (80ms stagger), charts in separate `StaggeredEntrance` (100ms stagger, sequenced after stats)
    - Replace loading with `ShimmerSkeleton` using `SkeletonShapes.chartBlock()` and `SkeletonShapes.statRow()`
    - Wrap score values with `CountUpText` and progress rings with `AnimatedProgressRing`
    - Add `EmptyStateView` with chart-building Lottie animation when no analytics data exists
    - _Requirements: 3.3, 3.5, 4.3, 5.1, 5.2, 9.2_

  - [x] 6.6 Integrate into Profile screen and bottom navigation
    - Apply `crossFadeRoute()` (250ms) for bottom navigation tab switches
    - Wrap toggle/switch elements on profile page with spring curve animation (250ms)
    - Add `EmptyStateView` with looping animation when no training sessions exist
    - Replace any `showModalBottomSheet` calls with `showAnimatedBottomSheet()` (spring-damped)
    - Replace any confirmation dialogs with `showAnimatedDialog()` (scale + fade)
    - _Requirements: 1.4, 2.4, 8.1, 8.2, 8.3, 8.4, 9.1_

- [x] 7. Checkpoint - Verify integrations compile
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Widget tests for shared animation components
  - [x] 8.1 Write widget tests for micro-interaction (`test/shared/animations/micro_interaction_test.dart`)
    - Test `Pressable`: verify scale transform on tap down/up, verify `onTap` callback fires
    - Test `PressableCard`: verify elevation increase during press
    - _Requirements: 2.1, 2.2_

  - [x] 8.2 Write widget tests for entrance animation (`test/shared/animations/entrance_animation_test.dart`)
    - Verify children are invisible at t=0
    - Verify partially visible mid-animation via `tester.pump()`
    - Verify fully visible after `tester.pumpAndSettle()`
    - Verify no re-animation on widget rebuild
    - _Requirements: 4.1, 4.4_

  - [x] 8.3 Write widget tests for metric animator (`test/shared/animations/metric_animator_test.dart`)
    - Test `CountUpText`: shows "0" initially, intermediate value mid-pump, final value after duration
    - Test `AnimatedProgressRing`: ring progress at 0 initially, target value after settle
    - _Requirements: 5.1, 5.2_

  - [x] 8.4 Write widget tests for page transitions (`test/shared/animations/page_transitions_test.dart`)
    - Verify `slideForwardRoute` produces a route that transitions with slide+fade
    - Verify `scaleWelcomeRoute` produces a route that transitions with scale+fade
    - Verify durations match spec (400ms, 500ms respectively)
    - _Requirements: 1.1, 1.5_

  - [x] 8.5 Write widget tests for shimmer skeleton (`test/shared/widgets/shimmer_skeleton_test.dart`)
    - Verify shimmer animation is running (widget renders)
    - Verify `SkeletonShapes` factory methods produce correctly sized containers
    - _Requirements: 3.1, 3.4_

  - [x] 8.6 Write widget tests for glass card (`test/shared/widgets/glass_card_test.dart`)
    - Verify `BackdropFilter` is present in widget tree
    - Verify border radius matches config
    - Verify dark variant uses correct fill color and blur sigma
    - _Requirements: 7.1, 7.3_

  - [x] 8.7 Write widget tests for empty state view (`test/shared/widgets/empty_state_view_test.dart`)
    - Verify headline and body text render
    - Verify CTA button renders when `ctaLabel` provided
    - Verify illustration respects 200×200 size constraint
    - _Requirements: 9.3, 9.4_

  - [x] 8.8 Write widget tests for animated bottom sheet (`test/shared/widgets/animated_bottom_sheet_test.dart`)
    - Verify sheet appears when `showAnimatedBottomSheet` is called
    - Verify dismiss behavior removes sheet from tree
    - _Requirements: 8.1, 8.2_

- [x] 9. Final validation pass
  - [x] 9.1 Run dart analyze and fix any issues
    - Run `dart analyze` in `mobile/vocal_coach_app/` and resolve all warnings/errors
    - Ensure zero issues reported
    - _Requirements: All_

  - [x] 9.2 Run flutter build and verify success
    - Run `flutter build apk --debug` in `mobile/vocal_coach_app/`
    - Ensure build completes successfully with no errors
    - _Requirements: All_

- [x] 10. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- No property-based tests — the design explicitly states PBT is not applicable for visual/animation work
- Widget tests use Flutter's `tester.pump()` and `tester.pumpAndSettle()` for animation timing verification
- All shared components use `const` constructors where possible per coding standards
- Dispose all `AnimationController`s in `dispose()` and check `mounted` before `setState`
- Performance constraint: max 3 `GlassCard` per screen, stagger capped at 10 items

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3"] },
    { "id": 3, "tasks": ["4.1", "4.2", "4.3", "4.4"] },
    { "id": 4, "tasks": ["4.5", "4.6", "4.7"] },
    { "id": 5, "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5", "6.6"] },
    { "id": 6, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8"] },
    { "id": 7, "tasks": ["9.1"] },
    { "id": 8, "tasks": ["9.2"] }
  ]
}
```
