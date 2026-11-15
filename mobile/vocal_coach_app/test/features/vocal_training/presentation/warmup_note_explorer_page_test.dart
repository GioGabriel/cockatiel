import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/live_audio_analyzer.dart';
import 'package:vocal_coach_app/features/vocal_training/presentation/warmup_note_explorer_page.dart';

class _FakeLiveAudioAnalyzer extends LiveAudioAnalyzer {
  _FakeLiveAudioAnalyzer() : super();

  final StreamController<LiveAudioFrame> _controller =
      StreamController<LiveAudioFrame>.broadcast();

  @override
  Stream<LiveAudioFrame> get frames => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void emit({required double frequencyHz, double loudnessDb = -20}) {
    _controller.add(
      LiveAudioFrame(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        loudnessDb: loudnessDb,
        frequencyHz: frequencyHz,
        voiced: true,
        confidence: 0.9,
        clippingRatio: 0,
        periodicity: 0.9,
      ),
    );
  }
}

class _DelayedStartLiveAudioAnalyzer extends _FakeLiveAudioAnalyzer {
  final Completer<void> startGate = Completer<void>();
  var disposedWhileStarting = false;

  @override
  Future<void> start() async {
    await startGate.future;
  }

  @override
  Future<void> dispose() async {
    disposedWhileStarting = !startGate.isCompleted;
    await super.dispose();
  }
}

Widget _page(_FakeLiveAudioAnalyzer analyzer) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: WarmupNoteExplorerPage(
      tonicKey: 'C',
      octave: 4,
      analyzerFactory: () => analyzer,
    ),
  );
}

void main() {
  test('warmup targets expose the pentachord and full octave accurately', () {
    final targets = warmupNoteTargets(tonicKey: 'C', octave: 4);

    expect(
      targets.map((target) => target.label),
      ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti', 'Do′'],
    );
    expect(targets.first.noteName, 'C4');
    expect(targets.first.frequencyHz, closeTo(261.6256, 0.01));
    expect(targets.last.noteName, 'C5');
    expect(targets.last.frequencyHz, closeTo(523.251, 0.01));
  });

  testWidgets('starts safely with no measurable microphone frame',
      (tester) async {
    final analyzer = _FakeLiveAudioAnalyzer();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(_page(analyzer));
    await tester.pump();

    expect(find.text('Warm up & find your starting note'), findsOneWidget);
    expect(find.text('Start when you’re ready'), findsOneWidget);
    expect(find.byKey(const Key('warmup-pitch-meter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waits for microphone startup before disposing its recorder',
      (tester) async {
    final analyzer = _DelayedStartLiveAudioAnalyzer();

    await tester.pumpWidget(_page(analyzer));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    analyzer.startGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(analyzer.disposedWhileStarting, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a tab changes the target without starting a score',
      (tester) async {
    final analyzer = _FakeLiveAudioAnalyzer();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(_page(analyzer));
    await tester.pump();
    await tester.tap(find.byKey(const Key('warmup-note-Re')));
    await tester.pump();

    expect(find.text('Target Re'), findsOneWidget);
    expect(find.textContaining('D4 · 293.7 Hz'), findsOneWidget);
    expect(find.text('No score is recorded during warm-up.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows direction and stable match only after repeated evidence',
      (tester) async {
    final analyzer = _FakeLiveAudioAnalyzer();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(_page(analyzer));
    await tester.pump();

    analyzer.emit(frequencyHz: 246.9417);
    await tester.pump();
    expect(find.text('A little higher'), findsNothing);

    analyzer.emit(frequencyHz: 246.9417);
    await tester.pump();
    expect(find.text('A little higher'), findsOneWidget);

    analyzer.emit(frequencyHz: 261.6256);
    analyzer.emit(frequencyHz: 261.6256);
    await tester.pump();

    expect(find.text('On target'), findsOneWidget);
    expect(find.byKey(const Key('warmup-stable-match')), findsOneWidget);
    expect(find.text('Perfect'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
