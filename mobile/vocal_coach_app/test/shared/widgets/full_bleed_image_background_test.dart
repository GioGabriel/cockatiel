import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/full_bleed_image_background.dart';

void main() {
  testWidgets('keeps the hero image full bleed with a readable overlay',
      (WidgetTester tester) async {
    const assetPath = 'assets/images/auth_3d_elements.jpg';

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 800,
          child: FullBleedImageBackground(
            assetPath: assetPath,
            semanticLabel: 'Microphone and music notes',
            child: Text('Content'),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('full-bleed-image-$assetPath')),
    );
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.topCenter);
    expect(find.bySemanticsLabel('Microphone and music notes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('full-bleed-image-overlay-$assetPath')),
      findsOneWidget,
    );
    expect(find.text('Content'), findsOneWidget);

    final overlay = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('full-bleed-image-overlay-$assetPath')),
    );
    final decoration = overlay.decoration as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
  });
}
