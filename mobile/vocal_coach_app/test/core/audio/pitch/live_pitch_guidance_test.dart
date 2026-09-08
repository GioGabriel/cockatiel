import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/pitch/live_pitch_guidance.dart';

void main() {
  test('debounces direction changes and uses cents-based language', () {
    final controller = LivePitchGuidanceController(requiredStableFrames: 2);

    expect(
      controller
          .update(
            isAttemptRunning: false,
            hasTarget: true,
            voiced: false,
            confidence: 0,
            loudnessDb: -30,
            centsError: 0,
          )
          .cue,
      LivePitchCue.startWhenReady,
    );

    controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: -78,
    );
    final low = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: -78,
    );
    expect(low.cue, LivePitchCue.tooLow);
    expect(low.message, 'A little higher');

    controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: -8,
    );
    final onTarget = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: -8,
    );
    expect(onTarget.cue, LivePitchCue.onTarget);
    expect(onTarget.message, 'On target');
  });

  test('separates signal quality and rest guidance from pitch direction', () {
    final controller = LivePitchGuidanceController(requiredStableFrames: 1);

    expect(
      controller
          .update(
            isAttemptRunning: true,
            hasTarget: true,
            voiced: false,
            confidence: 0,
            loudnessDb: -58,
            centsError: 0,
          )
          .cue,
      LivePitchCue.tooQuiet,
    );
    expect(
      controller
          .update(
            isAttemptRunning: true,
            hasTarget: true,
            voiced: false,
            confidence: 0.1,
            loudnessDb: -30,
            centsError: 0,
          )
          .cue,
      LivePitchCue.noClearNote,
    );
    expect(
      controller
          .update(
            isAttemptRunning: true,
            hasTarget: false,
            voiced: false,
            confidence: 0,
            loudnessDb: -30,
            centsError: 0,
          )
          .cue,
      LivePitchCue.takeBreath,
    );
    expect(
      controller
          .update(
            isAttemptRunning: true,
            hasTarget: true,
            voiced: true,
            confidence: 0.9,
            loudnessDb: -2,
            centsError: 0,
            clippingRatio: 0.2,
          )
          .cue,
      LivePitchCue.tooLoud,
    );
  });

  test('golden thresholds preserve monotonic pitch direction', () {
    final controller = LivePitchGuidanceController(requiredStableFrames: 1);

    final below = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: -31,
    );
    final above = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: 31,
    );

    expect(below.cue, LivePitchCue.tooLow);
    expect(above.cue, LivePitchCue.tooHigh);
  });

  test('uses the configured signal floor without requiring a loud voice', () {
    final controller = LivePitchGuidanceController(requiredStableFrames: 1);

    final quietButMeasurable = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.8,
      loudnessDb: -41,
      centsError: 4,
      quietFloorDb: -42,
    );

    expect(quietButMeasurable.cue, LivePitchCue.onTarget);
    expect(controller.lastFrameMeasurable, isTrue);

    final quiet = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.8,
      loudnessDb: -43,
      centsError: 4,
      quietFloorDb: -42,
    );
    expect(quiet.cue, LivePitchCue.tooQuiet);
    expect(controller.lastFrameMeasurable, isFalse);
  });

  test(
      'a rejected frame creates a non-measurable gap even when the cue is debounced',
      () {
    final controller = LivePitchGuidanceController(requiredStableFrames: 2);

    controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: 0,
    );
    final stable = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: true,
      confidence: 0.9,
      loudnessDb: -24,
      centsError: 0,
    );
    expect(stable.cue, LivePitchCue.onTarget);

    final rejected = controller.update(
      isAttemptRunning: true,
      hasTarget: true,
      voiced: false,
      confidence: 0,
      loudnessDb: -30,
      centsError: 0,
    );

    expect(rejected.cue, LivePitchCue.onTarget);
    expect(controller.lastFrameMeasurable, isFalse);
  });
}
