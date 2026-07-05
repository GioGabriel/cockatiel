import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/animations/micro_interaction.dart';

void main() {
  group('Pressable', () {
    testWidgets('scales down on tap down and back on tap up',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Pressable(
                onTap: () {},
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      // Find the Transform widget that is a descendant of Pressable
      final transformFinder = find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(Transform),
      );

      // Before press: scale should be 1.0
      var transform = tester.widget<Transform>(transformFinder.first);
      var scaleX = transform.transform.getColumn(0).x;
      expect(scaleX, closeTo(1.0, 0.01));

      // Start press gesture
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pumpAndSettle();

      // During press: scale should be 0.96 (default scaleDown)
      transform = tester.widget<Transform>(transformFinder.first);
      scaleX = transform.transform.getColumn(0).x;
      expect(scaleX, closeTo(0.96, 0.01));

      // Release
      await gesture.up();
      await tester.pumpAndSettle();

      // After release: scale should be back to 1.0
      transform = tester.widget<Transform>(transformFinder.first);
      final scaleAfter = transform.transform.getColumn(0).x;
      expect(scaleAfter, closeTo(1.0, 0.01));
    });

    testWidgets('fires onTap callback on tap up',
        (WidgetTester tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Pressable(
                onTap: () => tapCount++,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      // Use startGesture to send tap down then up
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tapCount, equals(1));
    });

    testWidgets('does not fire onTap on tap cancel',
        (WidgetTester tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Pressable(
                onTap: () => tapCount++,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump();
      // Cancel by moving far away
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(tapCount, equals(0));
    });
  });

  group('PressableCard', () {
    testWidgets('increases elevation during press',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressableCard(
                onTap: () {},
                baseElevation: 2.0,
                pressedElevation: 8.0,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      // Before press: elevation should be base (2.0)
      var card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, closeTo(2.0, 0.01));

      // Start press
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableCard)),
      );
      await tester.pumpAndSettle();

      // During press: elevation should be pressed (8.0)
      card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, closeTo(8.0, 0.01));

      // Release
      await gesture.up();
      await tester.pumpAndSettle();

      // After release: elevation returns to base
      card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, closeTo(2.0, 0.01));
    });

    testWidgets('scales down during press',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressableCard(
                onTap: () {},
                scaleDown: 0.97,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      final transformFinder = find.descendant(
        of: find.byType(PressableCard),
        matching: find.byType(Transform),
      );

      // Start press
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableCard)),
      );
      await tester.pumpAndSettle();

      // During press: scale should be 0.97
      final transform = tester.widget<Transform>(transformFinder.first);
      final scaleX = transform.transform.getColumn(0).x;
      expect(scaleX, closeTo(0.97, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('fires onTap callback on tap',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressableCard(
                onTap: () => tapped = true,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableCard)),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
