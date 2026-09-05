import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/contained_hero_image.dart';

void main() {
  testWidgets('keeps the complete square hero artwork visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 420,
          child: ContainedHeroImage(
            assetPath: 'assets/images/onboarding_collage.jpg',
            semanticLabel: 'Singers practicing with microphones',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(
        const ValueKey(
          'contained-hero-image-assets/images/onboarding_collage.jpg',
        ),
      ),
    );

    expect(image.fit, BoxFit.contain);
    expect(image.width, double.infinity);
    expect(image.height, double.infinity);
    expect(find.bySemanticsLabel('Singers practicing with microphones'),
        findsOneWidget);
  });
}
