import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/user_profile/presentation/voice_calibration_page.dart';

void main() {
  testWidgets('voice calibration intro scrolls on a compact viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceCalibrationPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Let\'s find your voice type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
