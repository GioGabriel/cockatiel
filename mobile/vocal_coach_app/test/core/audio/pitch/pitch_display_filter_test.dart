import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/core/audio/pitch/pitch_display_filter.dart';

void main() {
  test('requires repeated pitch and ignores isolated octave jumps', () {
    final filter = PitchDisplayFilter();
    expect(filter.update(220), isNull);
    expect(filter.update(221), closeTo(221, .1));
    expect(filter.update(880), closeTo(221, .1));
    expect(filter.update(220), closeTo(220, .1));
    expect(filter.update(440), closeTo(220, .1));
    expect(filter.update(441), closeTo(441, .1));
    expect(filter.update(null), isNull);
    expect(filter.update(440), isNull);
    expect(filter.update(double.nan), isNull);
  });
}
