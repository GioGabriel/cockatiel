import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/onboarding/presentation/onboarding_page.dart';

void main() {
  testWidgets('uses the full-bleed onboarding composition',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: OnboardingPage(onComplete: () {}),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('full-bleed-image-assets/images/onboarding_collage.jpg'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'full-bleed-image-overlay-assets/images/onboarding_collage.jpg',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Next'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('onboarding-login-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-primary-action')),
        findsOneWidget);
  });
}
