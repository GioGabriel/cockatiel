import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/animated_bottom_sheet.dart';

void main() {
  group('showAnimatedBottomSheet', () {
    testWidgets('sheet appears when called', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAnimatedBottomSheet(
                      context,
                      builder: (_) => const SizedBox(
                        height: 200,
                        child: Text('Sheet Content'),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Sheet content should not be present initially
      expect(find.text('Sheet Content'), findsNothing);

      // Tap button to show the bottom sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Sheet content should now be visible
      expect(find.text('Sheet Content'), findsOneWidget);
    });

    testWidgets('dismiss removes sheet from tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAnimatedBottomSheet(
                      context,
                      builder: (_) => const SizedBox(
                        height: 200,
                        child: Text('Sheet Content'),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Content'), findsOneWidget);

      // Tap the scrim/barrier to dismiss
      // The scrim is rendered behind the sheet as a ModalBarrier
      final scrimFinder = find.byType(ModalBarrier).last;
      await tester.tapAt(tester.getCenter(scrimFinder));
      await tester.pumpAndSettle();

      // Sheet content should be gone
      expect(find.text('Sheet Content'), findsNothing);
    });
  });

  group('showAnimatedDialog', () {
    testWidgets('dialog appears when called', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAnimatedDialog(
                      context,
                      builder: (_) => const AlertDialog(
                        content: Text('Dialog Content'),
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Dialog should not be present initially
      expect(find.text('Dialog Content'), findsNothing);

      // Tap button to show the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog content should now be visible
      expect(find.text('Dialog Content'), findsOneWidget);
    });

    testWidgets('dialog dismissed when barrier tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAnimatedDialog(
                      context,
                      builder: (_) => const AlertDialog(
                        content: Text('Dialog Content'),
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog Content'), findsOneWidget);

      // Tap outside the dialog to dismiss (top-left corner)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(find.text('Dialog Content'), findsNothing);
    });
  });
}
