import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/animated_cockatiel_splash.dart';

void main() {
  testWidgets('renders animated artwork and the Cockatiel wordmark',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(enableVideo: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('cockatiel-splash-artwork')),
      findsOneWidget,
    );
    expect(find.text('Cockatiel'), findsOneWidget);
    expect(find.text('Voice practice, made clear'), findsNothing);
    expect(find.bySemanticsLabel('Cockatiel vocal coaching artwork'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('cockatiel-splash-animation-layer')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('cockatiel-splash-wordmark')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('cockatiel-splash-progress')), findsNothing);

    await tester.pump(const Duration(milliseconds: 2400));
    final splashRect = tester.getRect(find.byType(AnimatedCockatielSplash));
    final artworkRect = tester.getRect(
      find.byKey(const ValueKey('cockatiel-splash-artwork')),
    );
    expect(artworkRect.center.dx, closeTo(splashRect.center.dx, 0.1));
    // The artwork intentionally sits above center to leave room for the
    // visible Cockatiel wordmark below it.
    expect(artworkRect.center.dy, lessThan(splashRect.center.dy));
    expect(artworkRect.width, greaterThan(0));
    expect(artworkRect.height, greaterThan(0));
  });

  testWidgets(
      'advances through real sprite frames instead of shaking one image',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(enableVideo: false),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final firstFrame = tester.widget<Image>(
      find.byKey(const ValueKey('cockatiel-splash-artwork')),
    );

    await tester.pump(const Duration(milliseconds: 800));
    final middleFrame = tester.widget<Image>(
      find.byKey(const ValueKey('cockatiel-splash-artwork')),
    );

    expect(
      (middleFrame.image as AssetImage).assetName,
      isNot(equals((firstFrame.image as AssetImage).assetName)),
    );
    expect(find.byKey(const ValueKey('cockatiel-splash-wordmark')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completes the finite flight sequence without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(enableVideo: false),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1900));
    // A finite splash must settle. This deliberately catches an accidental
    // repeat() ticker that would keep the auth gate looking permanently busy.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(tester.takeException(), isNull);
    expect(
        find.byKey(const ValueKey('cockatiel-splash-artwork')), findsOneWidget);
    expect(find.byKey(const ValueKey('cockatiel-splash-animation-layer')),
        findsOneWidget);
  });

  testWidgets('uses a static readable state when motion is disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AnimatedCockatielSplash(enableVideo: false),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
        find.byKey(const ValueKey('cockatiel-splash-artwork')), findsOneWidget);
    expect(find.byKey(const ValueKey('cockatiel-splash-animation-layer')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Cockatiel vocal coaching artwork'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the layered animation alive while startup is pending',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(enableVideo: false),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('cockatiel-splash-animation-layer')),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a branded fallback when the artwork is unavailable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(
            assetPath: 'assets/images/does_not_exist.png',
            enableVideo: false,
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

  testWidgets('falls back safely when the video backend is unavailable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCockatielSplash(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('cockatiel-splash-artwork')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
