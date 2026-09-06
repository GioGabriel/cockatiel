import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web splash uses the production video as a full-bleed source', () {
    final markup = File('web/index.html').readAsStringSync();

    expect(markup, contains('id="splash-video"'));
    expect(markup, contains('assets/assets/videos/cockatiel_splash.mp4'));
    expect(markup, contains('object-fit: cover'));
    expect(markup, contains('@media (min-aspect-ratio: 3/4)'));
    expect(markup, contains('object-fit: contain'));
    expect(markup, contains('autoplay'));
    expect(markup, contains('playsinline'));
    expect(markup, contains('id="splash-sound-toggle"'));
    expect(markup, contains('aria-label="Enable splash sound"'));
    expect(markup, contains('splashVideo.muted = false'));
    expect(markup, contains('splashVideo.volume = 1'));
    expect(markup, contains('splashVideo.addEventListener(\'error\''));
    expect(markup, contains("splashVideo.addEventListener('ended'"));
  });

  test('web splash has a bounded fallback and auth handoff', () {
    final markup = File('web/index.html').readAsStringSync();

    expect(markup, contains('const splashMinimumDurationMs = 900;'));
    expect(markup, contains('const splashMaximumDurationMs = 8000;'));
    expect(markup, contains("'flutter-first-frame'"));
    expect(markup, contains('videoEnded'));
    expect(markup, contains('dismissSplash(true)'));
  });
}
