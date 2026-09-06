import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/scrollable_action_layout.dart';

void main() {
  testWidgets(
      'scrolls lengthy content while keeping the primary action visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollableActionLayout(
            content: Card(
              child: SizedBox(
                height: 1000,
                child: Center(child: Text('Briefing content')),
              ),
            ),
            action: FilledButton(
              key: ValueKey('primary-action'),
              onPressed: null,
              child: Text('Start session'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const ValueKey('primary-action')), findsOneWidget);

    final actionRect =
        tester.getRect(find.byKey(const ValueKey('primary-action')));
    expect(actionRect.top, greaterThanOrEqualTo(0));
    expect(actionRect.bottom, lessThanOrEqualTo(420));
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();

    expect(find.text('Briefing content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an error message in the scrollable content region',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollableActionLayout(
            content: SizedBox(height: 360),
            error: Text('Could not start session'),
            action: FilledButton(
              onPressed: null,
              child: Text('Start session'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not start session'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
