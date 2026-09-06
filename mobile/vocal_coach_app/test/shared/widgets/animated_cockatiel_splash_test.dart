import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/animated_cockatiel_splash.dart';

void main() {
  testWidgets('renders branded artwork with accessible loading context',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(
            showProgress: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('cockatiel-splash-artwork')),
      findsOneWidget,
    );
    expect(find.text('Cockatiel'), findsOneWidget);
    expect(find.text('Voice practice, made clear'), findsOneWidget);
    expect(find.bySemanticsLabel('Cockatiel vocal coaching artwork'),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('cockatiel-splash-motion-layer')),
      findsOneWidget,
    );

    final splashRect = tester.getRect(find.byType(AnimatedCockatielSplash));
    final progressRect = tester.getRect(
      find.byKey(const ValueKey('cockatiel-splash-progress')),
    );
    expect(progressRect.center.dx, closeTo(splashRect.center.dx, 1));
  });

  testWidgets('completes the staged entrance without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(showProgress: true),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1_600));

    expect(tester.takeException(), isNull);
    expect(find.text('Cockatiel'), findsOneWidget);
  });

  testWidgets('uses a static readable state when motion is disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AnimatedCockatielSplash(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cockatiel'), findsOneWidget);
    expect(find.bySemanticsLabel('Cockatiel vocal coaching artwork'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a branded fallback when the artwork is unavailable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(
            assetPath: 'assets/images/does_not_exist.png',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('cockatiel-splash-artwork-fallback')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
