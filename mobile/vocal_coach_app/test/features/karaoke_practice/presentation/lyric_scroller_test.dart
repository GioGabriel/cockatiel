import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/widgets/lyric_scroller.dart';

void main() {
  testWidgets(
      'untimed lyrics remain readable and are labelled without fake synchronization',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 180,
                child: LyricScroller(
                    lyrics: [],
                    plainLyrics: 'First line\nSecond line',
                    currentPosition: Duration(seconds: 30))))));
    expect(find.text('Lyrics • scroll at your own pace'), findsOneWidget);
    expect(find.text('First line\nSecond line'), findsOneWidget);
    expect(find.textContaining('Current lyric:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
