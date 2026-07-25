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
    testWidgets('does NOT have BackdropFilter in widget tree (matte design)', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('border radius matches config', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard(
            borderRadius: 16.0,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(16.0),
      );
    });

    testWidgets('default border radius is 24', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(24.0),
      );
    });

    testWidgets('default fill color falls back to theme surface (0xFFF5F5F5 in light mode)', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFF5F5F5));
    });
  });

  group('GlassCard.dark', () {
    testWidgets('uses dark fill color Color(0xFF181818)', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard.dark(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF181818));
    });

    testWidgets('does NOT have BackdropFilter in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard.dark(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('GlassCard.disabled', () {
    testWidgets('does NOT have BackdropFilter in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard.disabled(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('does NOT have ClipRRect in widget tree', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const GlassCard.disabled(
            child: SizedBox(width: 100, height: 100),
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
