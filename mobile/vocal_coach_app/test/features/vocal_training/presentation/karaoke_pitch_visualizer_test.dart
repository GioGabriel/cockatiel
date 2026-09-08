import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/pitch/live_pitch_guidance.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/widgets/karaoke_pitch_visualizer.dart';
import 'package:vocal_coach_app/shared/models/session_models.dart';

void main() {
  testWidgets('shows tuner guidance and accessible pitch labels at large text',
      (tester) async {
    final stage = TrainingRuntimeStage(
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

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: KaraokePitchVisualizer(
                stages: [stage],
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
}
