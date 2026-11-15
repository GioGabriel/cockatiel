import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/pitch/live_pitch_guidance.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/widgets/karaoke_pitch_visualizer.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

TrainingRuntimeStage _stage() {
  return TrainingRuntimeStage(
    stageId: 'stage-do',
    title: 'Do',
    targetLabel: 'Do',
    instruction: 'Match the note.',
    durationSec: 2,
    startSec: 0,
    endSec: 2,
    target: TrainingTarget(
      targetId: 'stage-do',
      solfege: 'Do',
      scaleDegree: 1,
      midiNote: 60,
      frequencyHz: 261.63,
      key: 'C',
      octave: 4,
      startSec: 0,
      endSec: 2,
      intendedNoteDurationSec: 2,
      restAfterSec: 0,
      targetType: 'sustained_note',
      breathCue: false,
    ),
  );
}

Widget _visualizer({
  required double? detectedFrequencyHz,
  double? detectedCents,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SizedBox(
        height: 360,
        child: KaraokePitchVisualizer(
          stages: [_stage()],
          currentElapsedSec: 0.5,
          pitchHistory: const [
            PitchPoint(0.1, 0),
            PitchPoint(0.4, 261.63),
          ],
          minHz: 120,
          maxHz: 520,
          getTargetFrequency: (_) => 261.63,
          isRunning: true,
          targetLabel: 'Do',
          detectedNoteLabel: detectedFrequencyHz == null ? null : 'C4',
          detectedFrequencyHz: detectedFrequencyHz,
          detectedCents:
              detectedCents ?? (detectedFrequencyHz == null ? null : 0),
          guidance: LivePitchGuidance(
            cue: detectedFrequencyHz == null
                ? LivePitchCue.noClearNote
                : LivePitchCue.onTarget,
            centsError: 0,
            confidence: detectedFrequencyHz == null ? 0 : 0.9,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows tuner guidance and accessible pitch labels at large text',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: KaraokePitchVisualizer(
                stages: [_stage()],
                currentElapsedSec: 0.5,
                pitchHistory: const [
                  PitchPoint(0.1, 0),
                  PitchPoint(0.4, 261.63)
                ],
                minHz: 120,
                maxHz: 520,
                getTargetFrequency: (_) => 261.63,
                isRunning: true,
                targetLabel: 'Do',
                detectedNoteLabel: 'C4',
                detectedFrequencyHz: 261.63,
                detectedCents: 0,
                guidance: const LivePitchGuidance(
                  cue: LivePitchCue.onTarget,
                  centsError: 0,
                  confidence: 0.9,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('On target'), findsOneWidget);
    expect(find.textContaining('Estimated fundamental pitch'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(KaraokePitchVisualizer));
    expect(semantics.label, contains('Pitch tuner. Target Do. Detected C4.'));
    expect(semantics.label, contains('On target'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays stable before the first measurable microphone frame',
      (tester) async {
    await tester.pumpWidget(_visualizer(detectedFrequencyHz: null));

    expect(find.text('I can’t hear a clear note yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show a debounced pitch cue without a current marker',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: KaraokePitchVisualizer(
              stages: [_stage()],
              currentElapsedSec: 0.5,
              pitchHistory: const [PitchPoint(0.1, 0)],
              minHz: 120,
              maxHz: 520,
              getTargetFrequency: (_) => 261.63,
              isRunning: true,
              targetLabel: 'Do',
              guidance: const LivePitchGuidance(
                cue: LivePitchCue.onTarget,
                centsError: 0,
                confidence: 0.9,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('I can’t hear a clear note yet'), findsOneWidget);
    expect(find.text('On target'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show stale cents when the current note is unavailable',
      (tester) async {
    await tester.pumpWidget(
      _visualizer(detectedFrequencyHz: null, detectedCents: 420),
    );

    expect(find.text('+420 cents'), findsNothing);
    expect(find.text('I can’t hear a clear note yet'), findsOneWidget);
  });

  testWidgets('keeps live guidance inside the pitch-map surface',
      (tester) async {
    await tester.pumpWidget(_visualizer(detectedFrequencyHz: 261.63));

    final mapSurface = find.byKey(const Key('pitch-map-surface'));
    final overlay = find.byKey(const Key('pitch-tuner-overlay'));
    expect(
      find.descendant(of: mapSurface, matching: overlay),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('On target')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('animates measurable to unavailable and back without crashing',
      (tester) async {
    await tester.pumpWidget(_visualizer(detectedFrequencyHz: 261.63));
    await tester.pump(const Duration(milliseconds: 40));

    await tester.pumpWidget(_visualizer(detectedFrequencyHz: null));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_visualizer(detectedFrequencyHz: 293.66));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles repeated live frequency updates while animating',
      (tester) async {
    await tester.pumpWidget(_visualizer(detectedFrequencyHz: 261.63));

    for (final frequency in <double>[262.2, 260.8, 264.0, 258.5, 261.63]) {
      await tester.pumpWidget(_visualizer(detectedFrequencyHz: frequency));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }
  });

  test('higher frequencies map visually above lower frequencies', () {
    final lowerY = pitchMapYForFrequency(
      220,
      minHz: 100,
      maxHz: 880,
      height: 200,
    );
    final higherY = pitchMapYForFrequency(
      440,
      minHz: 100,
      maxHz: 880,
      height: 200,
    );

    expect(higherY, lessThan(lowerY));
    expect(
      pitchMapYForFrequency(
        0,
        minHz: 100,
        maxHz: 880,
        height: 200,
      ),
      greaterThan(200),
    );
  });

  test('invalid plot height never produces a non-finite marker coordinate', () {
    final y = pitchMapYForFrequency(
      440,
      minHz: 100,
      maxHz: 880,
      height: double.nan,
    );

    expect(y.isFinite, isTrue);
  });
}
