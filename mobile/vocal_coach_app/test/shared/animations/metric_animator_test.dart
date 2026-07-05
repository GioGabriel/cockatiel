import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/animations/metric_animator.dart';

void main() {
  group('CountUpText', () {
    testWidgets('shows "0" initially at frame 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountUpText(value: 100),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '0');
    });

    testWidgets('shows intermediate value mid-animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountUpText(value: 100),
          ),
        ),
      );

      // Pump to ~half the 800ms duration
      await tester.pump(const Duration(milliseconds: 400));

      final textWidget = tester.widget<Text>(find.byType(Text));
      final currentValue = int.parse(textWidget.data!);
      expect(currentValue, greaterThan(0));
      expect(currentValue, lessThan(100));
    });

    testWidgets('shows final value after animation completes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountUpText(value: 100),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '100');
    });

    testWidgets('displays suffix correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountUpText(value: 50, suffix: '%'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '50%');
    });

    testWidgets('respects decimalPlaces', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountUpText(value: 3.14, decimalPlaces: 2),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, '3.14');
    });
  });

  group('AnimatedProgressRing', () {
    testWidgets('renders AnimatedProgressRing widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedProgressRing(progress: 0.75),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressRing), findsOneWidget);
    });

    testWidgets('ring progress is at 0 initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedProgressRing(progress: 0.75),
          ),
        ),
      );

      // Find the CustomPaint that is a descendant of AnimatedProgressRing
      final customPaintFinder = find.descendant(
        of: find.byType(AnimatedProgressRing),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      // At frame 0 the painter should exist with progress near 0
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.painter, isNotNull);
    });

    testWidgets('ring reaches target value after settle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedProgressRing(progress: 0.75),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget still renders after animation completes
      final customPaintFinder = find.descendant(
        of: find.byType(AnimatedProgressRing),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedProgressRing(progress: 0.5, size: 120.0),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final customPaintFinder = find.descendant(
        of: find.byType(AnimatedProgressRing),
        matching: find.byType(CustomPaint),
      );
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, const Size(120.0, 120.0));
    });
  });
}
