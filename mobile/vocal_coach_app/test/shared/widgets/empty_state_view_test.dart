import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/empty_state_view.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('EmptyStateView', () {
    testWidgets('renders headline and body text', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const EmptyStateView(
            headline: 'No sessions yet',
            body: 'Start your first vocal training!',
          ),
        ),
      );

      expect(find.text('No sessions yet'), findsOneWidget);
      expect(find.text('Start your first vocal training!'), findsOneWidget);
    });

    testWidgets('renders CTA button when ctaLabel is provided',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildApp(
          EmptyStateView(
            headline: 'Empty',
            body: 'Nothing here',
            ctaLabel: 'Get Started',
            onCtaTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('does not render CTA button when ctaLabel is null',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          const EmptyStateView(
            headline: 'Empty',
            body: 'Nothing here',
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('illustration respects 200x200 size constraint',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          const EmptyStateView(
            headline: 'Empty',
            body: 'Nothing here',
          ),
        ),
      );

      // The default illustrationSize is 200, wrapped in a SizedBox
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == 200.0 &&
            widget.height == 200.0,
      );
      expect(sizedBoxFinder, findsOneWidget);
    });

    testWidgets('renders fallback icon when no lottieAsset or customAnimation',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          const EmptyStateView(
            headline: 'Empty',
            body: 'Nothing here',
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('renders customAnimation widget when provided',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          EmptyStateView(
            headline: 'Empty',
            body: 'Nothing here',
            customAnimation: Container(
              key: const Key('custom-anim'),
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom-anim')), findsOneWidget);
      // Fallback icon should not appear when custom animation is set
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('custom illustrationSize is respected', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const EmptyStateView(
            headline: 'Empty',
            body: 'Nothing here',
            illustrationSize: 150.0,
          ),
        ),
      );

      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == 150.0 &&
            widget.height == 150.0,
      );
      expect(sizedBoxFinder, findsOneWidget);
    });
  });
}
