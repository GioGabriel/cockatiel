import 'package:vocal_coach_app/features/karaoke_practice/domain/song_content_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/karaoke_practice/presentation/widgets/lyric_scroller.dart';

void main() {
  testWidgets(
      'karaoke highlights the current word and rewinds before the intro',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final lyrics = parseSongLyrics(
          '[00:02.00]<00:02.00>Sing <00:03.00>with <00:05.00>me<00:06.00>\n[00:08.00]Next phrase');
      Widget page(int ms) => MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  height: 240,
                  child: LyricScroller(
                      lyrics: lyrics,
                      currentPosition: Duration(milliseconds: ms)))));
      await tester.pumpWidget(page(3200));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Current word: with'), findsOneWidget);
      await tester.pumpWidget(page(5100));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Current word: me'), findsOneWidget);
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Current word:')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('line-only lyrics label estimated word guidance', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  height: 240,
                  child: LyricScroller(
                      lyrics: parseSongLyrics(
                          '[00:00.00]Sing with me\n[00:06.00]Next'),
                      currentPosition: const Duration(seconds: 3))))));
      expect(find.text('Word timing estimated'), findsOneWidget);
      expect(find.bySemanticsLabel('Current word: with'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('timed lyrics remain in the short player at text scale $scale',
        (tester) async {
      const viewport = Key('lyric-viewport');
      const lines = [
        LyricLine(
            time: Duration.zero, text: 'Sing gently into the next phrase'),
        LyricLine(time: Duration(seconds: 3), text: 'Let your voice flow')
      ];
      Widget page(Duration position) => MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      key: viewport,
                      width: 320,
                      height: 150,
                      child: MediaQuery(
                          data: MediaQueryData(
                              textScaler: TextScaler.linear(scale),
                              disableAnimations: true),
                          child: LyricScroller(
                              lyrics: lines, currentPosition: position))))));
      await tester.pumpWidget(page(Duration.zero));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byKey(viewport));
      var textBounds = tester.getRect(find.text(lines.first.text));
      expect(textBounds.top, greaterThanOrEqualTo(bounds.top));
      if (textBounds.height <= bounds.height) {
        expect(textBounds.bottom, lessThanOrEqualTo(bounds.bottom));
      }
      // A line taller than the player must get its own full-height row,
      // so it can be scrolled without overlapping the following lyric.
      final row = find
          .ancestor(
              of: find.text(lines.first.text), matching: find.byType(Semantics))
          .first;
      expect(
          tester.getSize(row).height, greaterThanOrEqualTo(textBounds.height));
      await tester.pumpWidget(page(const Duration(seconds: 3)));
      await tester.pumpAndSettle();
      textBounds = tester.getRect(find.text(lines.last.text));
      if (textBounds.height <= bounds.height) {
        expect(bounds.contains(textBounds.center), isTrue);
      } else {
        expect(textBounds.top, inInclusiveRange(bounds.top, bounds.bottom));
      }
      expect(tester.takeException(), isNull);
    });
  }

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
