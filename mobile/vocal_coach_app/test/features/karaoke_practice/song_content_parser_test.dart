import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/features/karaoke_practice/domain/song_content_parser.dart';

void main() {
  test('pitch points are chronological, finite, positive and unique', () {
    final stages = parseSongPitchMap([
      {'time': 2, 'pitch': 440},
      {'time': -1, 'pitch': 220},
      {'time': 0, 'pitch': 261.63},
      {'time': 0, 'pitch': 300},
      {'time': 1, 'pitch': double.nan},
      {'time': 3, 'pitch': 0},
    ]);
    expect(stages.map((stage) => stage.startSec), [0, 2]);
    expect(stages.first.target.frequencyHz, 261.63);
    expect(stages.first.endSec, lessThanOrEqualTo(0.5));
  });

  test('timestamp maps sort numerically and reject malformed times', () {
    final stages = parseSongPitchMap({
      '1:02.0': 440,
      '0:9.0': 220,
      '0:65': 330,
      '-1:00': 220,
      'bad': 220,
    });
    expect(stages.map((stage) => stage.startSec), [9, 62]);
  });

  test('lyrics support repeated timestamps, offsets and chronological order',
      () {
    final lyrics = parseSongLyrics(
      '[offset:500]\n[00:02.00]Second\n[00:00.00][00:01.00]First\n[ar:Artist]',
    );
    expect(lyrics.map((line) => line.time.inMilliseconds), [0, 500, 1500]);
    expect(lyrics.map((line) => line.text), ['First', 'First', 'Second']);
  });
}
