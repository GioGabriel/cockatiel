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

    final foregroundImage = tester.widget<Image>(
      find.byKey(
        const ValueKey(
          'contained-hero-image-assets/images/onboarding_collage.jpg',
        ),
      ),
    );

    expect(foregroundImage.fit, BoxFit.contain);
    expect(foregroundImage.width, double.infinity);
    expect(foregroundImage.height, double.infinity);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.bySemanticsLabel('Singers practicing with microphones'),
        findsOneWidget);
  });
}
