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
  });
}
