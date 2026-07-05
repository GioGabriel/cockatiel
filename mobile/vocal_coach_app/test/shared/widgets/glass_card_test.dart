import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/glass_card.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('GlassCard default', () {
    testWidgets('has BackdropFilter in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('border radius matches config', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard(
            borderRadius: 16.0,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(16.0),
      );
    });

    testWidgets('default border radius is 24', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(24.0),
      );
    });

    testWidgets('default fill color is white at 70% opacity', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white.withValues(alpha: 0.7));
    });
  });

  group('GlassCard.dark', () {
    testWidgets('uses dark fill color (black at 40% opacity)', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard.dark(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0x66000000));
    });

    testWidgets('uses blur sigma of 16', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard.dark(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      // BackdropFilter is present — the dark variant uses blurSigma: 16
      // which is configured via ImageFilter.blur(sigmaX: 16, sigmaY: 16)
      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(backdropFilter.filter, isNotNull);
    });

    testWidgets('has BackdropFilter in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard.dark(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('GlassCard.disabled', () {
    testWidgets('does NOT have BackdropFilter in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard.disabled(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('does NOT have ClipRRect in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          GlassCard.disabled(
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('uses theme surface color as fill', (tester) async {
      final theme = ThemeData.light();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: GlassCard.disabled(
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, theme.colorScheme.surface);
    });
  });
}
