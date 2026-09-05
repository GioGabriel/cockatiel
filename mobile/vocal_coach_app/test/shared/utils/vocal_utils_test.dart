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
}
