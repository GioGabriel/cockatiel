import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/animations/page_transitions.dart';

void main() {
  group('slideForwardRoute', () {
    testWidgets('produces a route with SlideTransition and FadeTransition',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  slideForwardRoute(
                    builder: (_) => const Scaffold(
                      body: Text('Forward Page'),
                    ),
                  ),
                );
              },
              child: const Text('Navigate'),
            ),
          ),
        ),
      );

      // Tap the button to trigger navigation
      await tester.tap(find.text('Navigate'));
      // Pump a single frame to start the transition
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify SlideTransition and FadeTransition are in the tree
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('has transitionDuration of 400ms', (WidgetTester tester) async {
      final route = slideForwardRoute(
        builder: (_) => const Scaffold(body: Text('Test')),
      );

      expect(
        route.transitionDuration,
        equals(const Duration(milliseconds: 400)),
      );
    });

    testWidgets('completes transition after pumping full duration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  slideForwardRoute(
                    builder: (_) => const Scaffold(
                      body: Text('Forward Page'),
                    ),
                  ),
                );
              },
              child: const Text('Navigate'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      // After settling, the destination page should be fully visible
      expect(find.text('Forward Page'), findsOneWidget);
    });
  });

  group('scaleWelcomeRoute', () {
    testWidgets('produces a route with ScaleTransition and FadeTransition',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  scaleWelcomeRoute(
                    builder: (_) => const Scaffold(
                      body: Text('Welcome Page'),
                    ),
                  ),
                );
              },
              child: const Text('Navigate'),
            ),
          ),
        ),
      );

      // Tap the button to trigger navigation
      await tester.tap(find.text('Navigate'));
      // Pump a single frame to start the transition
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify ScaleTransition and FadeTransition are in the tree
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('has transitionDuration of 500ms', (WidgetTester tester) async {
      final route = scaleWelcomeRoute(
        builder: (_) => const Scaffold(body: Text('Test')),
      );

      expect(
        route.transitionDuration,
        equals(const Duration(milliseconds: 500)),
      );
    });

    testWidgets('completes transition after pumping full duration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  scaleWelcomeRoute(
                    builder: (_) => const Scaffold(
                      body: Text('Welcome Page'),
                    ),
                  ),
                );
              },
              child: const Text('Navigate'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();

      // After settling, the destination page should be fully visible
      expect(find.text('Welcome Page'), findsOneWidget);
    });
  });
}
