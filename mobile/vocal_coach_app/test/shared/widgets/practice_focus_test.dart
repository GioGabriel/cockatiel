import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/practice_focus.dart';

void main() {
  testWidgets(
      'live practice keeps the visual and finish control usable at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var stopped = false;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
      child: PracticeFocus(
          title: 'Pitch matching',
          cue: 'Sing Do gently',
          secondsRemaining: 20,
          finishLabel: 'Stop take',
          progress: 0.4,
          visual: const Placeholder(),
          onFinish: () => stopped = true),
    )));
    expect(find.byKey(const Key('practice-focus-visual')), findsOneWidget);
    await tester.ensureVisible(find.text('Stop take'));
    await tester.tap(find.text('Stop take'));
    expect(stopped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
