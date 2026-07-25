import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/animations/entrance_animation.dart';

void main() {
  group('StaggeredEntrance', () {
    Widget buildTestWidget({
      List<Widget>? children,
      Duration staggerDelay = const Duration(milliseconds: 60),
      Duration itemDuration = const Duration(milliseconds: 400),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: StaggeredEntrance(
            staggerDelay: staggerDelay,
            itemDuration: itemDuration,
            children: children ??
                [
                  const Text('Item 1'),
                  const Text('Item 2'),
                  const Text('Item 3'),
                ],
          ),
        ),
      );
    }

    /// Finds FadeTransition widgets that are descendants of StaggeredEntrance.
    Finder fadeTransitionsInEntrance() {
      return find.descendant(
        of: find.byType(StaggeredEntrance),
        matching: find.byType(FadeTransition),
      );
    }

    testWidgets('children are invisible at t=0', (tester) async {
      // Use pump with zero duration to avoid any animation progress.
      // pumpWidget calls pump internally but we need the frame scheduled
      // without animation advancement.
      await tester.pumpWidget(buildTestWidget(), duration: Duration.zero);

      final fadeWidgets = tester.widgetList<FadeTransition>(
        fadeTransitionsInEntrance(),
      );

      expect(fadeWidgets.isNotEmpty, isTrue);
      for (final fade in fadeWidgets) {
        expect(
          fade.opacity.value,
          equals(0.0),
          reason: 'All children should start fully transparent',
        );
      }
    });

    testWidgets('children are partially visible mid-animation', (tester) async {
      await tester.pumpWidget(buildTestWidget(), duration: Duration.zero);

      // Total duration = 3 * 60ms + 400ms = 580ms
      // Pump 200ms — first item should have started animating
      await tester.pump(const Duration(milliseconds: 200));

      final fadeWidgets = tester.widgetList<FadeTransition>(
        fadeTransitionsInEntrance(),
      ).toList();

      expect(fadeWidgets.isNotEmpty, isTrue);

      // First item should have some opacity > 0
      expect(
        fadeWidgets[0].opacity.value,
        greaterThan(0.0),
        reason: 'First item should have started fading in',
      );

      // Last item should still be at 0 or very low opacity
      // (it starts at 2 * 60ms = 120ms offset, with 400ms duration)
      // At 200ms, last item is at (200-120)/580 of the total controller,
      // which means it's only barely started its interval.
      // Check that not all items are at full opacity.
      final hasNonFull = fadeWidgets.any(
        (fade) => fade.opacity.value < 1.0,
      );
      expect(
        hasNonFull,
        isTrue,
        reason: 'Not all items should be fully visible mid-animation',
      );
    });

    testWidgets('children are fully visible after pumpAndSettle', (tester) async {
      await tester.pumpWidget(buildTestWidget(), duration: Duration.zero);
      await tester.pumpAndSettle();

      // After animation completes, all text items should be visible
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // After _hasAnimated becomes true, children render directly
      // without FadeTransition wrappers within StaggeredEntrance.
      expect(fadeTransitionsInEntrance(), findsNothing);
    });

    testWidgets('no re-animation on widget rebuild', (tester) async {
      late StateSetter rebuildTrigger;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuildTrigger = setState;
                return const StaggeredEntrance(
                  children: [
                    Text('Item 1'),
                    Text('Item 2'),
                    Text('Item 3'),
                  ],
                );
              },
            ),
          ),
        ),
        duration: Duration.zero,
      );

      // Let animation complete
      await tester.pumpAndSettle();

      // Verify children are fully visible
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      expect(fadeTransitionsInEntrance(), findsNothing);

      // Trigger a rebuild
      rebuildTrigger(() {});
      await tester.pump();

      // After rebuild, children should remain fully visible without
      // FadeTransition wrappers being reintroduced (no re-animation)
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      expect(fadeTransitionsInEntrance(), findsNothing);
    });
  });
}
