import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_coach_app/shared/utils/vocal_utils.dart';

void main() {
  test('guided practice durations stay short and repeatable', () {
    expect(durationByDifficulty, {
      'beginner': 20,
      'intermediate': 30,
      'advanced': 45,
    });
  });

  test('canonical pitch labels resolve solfege, octaves, and accidentals', () {
    expect(
      frequencyHzForPitchLabel('Do', key: 'C', octave: 4),
      closeTo(261.6256, 0.01),
    );
    expect(
      frequencyHzForPitchLabel('La', key: 'C', octave: 4),
      closeTo(440, 0.01),
    );
    expect(
      frequencyHzForPitchLabel('Ti', key: 'C', octave: 4),
      closeTo(493.883, 0.01),
    );
    expect(
      frequencyHzForPitchLabel("Do′", key: 'C', octave: 4),
      closeTo(523.251, 0.01),
    );
    expect(frequencyHzForPitchLabel('C4'), closeTo(261.6256, 0.01));
    expect(frequencyHzForPitchLabel('Db4'), closeTo(277.183, 0.01));
    expect(frequencyHzForPitchLabel('E#4'), closeTo(349.228, 0.01));
    expect(frequencyHzForPitchLabel('Fb4'), closeTo(329.628, 0.01));
    expect(frequencyHzForPitchLabel('Cb4'), closeTo(246.942, 0.01));
    expect(frequencyHzForPitchLabel('B#3'), closeTo(261.626, 0.01));
    expect(
      frequencyHzForPitchLabel('Do', key: 'D♭', octave: 4),
      closeTo(277.183, 0.01),
    );
    expect(frequencyHzForPitchLabel('not-a-note'), isNull);
  });

  test('canonical cents direction is negative below and positive above', () {
    expect(centsErrorForFrequencies(220, 440), closeTo(-1200, 0.001));
    expect(centsErrorForFrequencies(880, 440), closeTo(1200, 0.001));
  });

  test('voice range bounds provide the map and estimator envelope', () {
    expect(vocalRangeFrequencyBounds('tenor'), {'min': 130.81, 'max': 523.25});
    expect(vocalRangeFrequencyBounds('baritone'), {'min': 110.0, 'max': 440.0});
    expect(vocalRangeFrequencyBounds('bass'), {'min': 82.0, 'max': 330.0});
    expect(vocalRangeFrequencyBounds('mezzo-soprano'), {
      'min': 220.0,
      'max': 880.0,
    });
  });
}
