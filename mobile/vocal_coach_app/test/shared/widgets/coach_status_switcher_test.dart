import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/widgets/coach_status_switcher.dart';

void main() {
  testWidgets(
    'handles a status returning during the outgoing animation',
    (tester) async {
      final status = ValueNotifier<String>('First cue');

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, value, __) => CoachStatusSwitcher(status: value),
          ),
        ),
      );
      await tester.pump();

      status.value = 'Second cue';
      await tester.pump(const Duration(milliseconds: 60));
      status.value = 'First cue';
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('First cue'), findsOneWidget);

      status.dispose();
    },
  );
}
