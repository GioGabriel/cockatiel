import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocal_coach_app/features/onboarding/presentation/onboarding_page.dart';

void main() {
  testWidgets('each onboarding step has an illustration matching its purpose',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      SharedPreferences.setMockInitialValues({});
      await tester
          .pumpWidget(MaterialApp(home: OnboardingPage(onComplete: () {})));
      expect(
          find.bySemanticsLabel(
              'Illustration of a microphone and flowing sound waves'),
          findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
          find.bySemanticsLabel(
              'Illustration of a pitch guide with a rising melody'),
          findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'Illustration of a microphone and flowing sound waves'),
          findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
          find.bySemanticsLabel(
              'Illustration of a record with synchronized lyric lines'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'onboarding explains the practice flow and can be skipped at large text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = false;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
      child: OnboardingPage(onComplete: () => completed = true),
    )));
    expect(find.text('Find your voice.\nMake it yours.'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-hero')), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
