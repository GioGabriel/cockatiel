
String formatDuration(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '${m}m ${s}s';
}

String formatSnakeCaseTitle(String snakeCase) {
  if (snakeCase.isEmpty) return snakeCase;
  return snakeCase.split('_').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

const keyOptions = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

const durationByDifficulty = {
  'beginner': 30,
  'intermediate': 45,
  'advanced': 60,
};

String displayMetricLabel(String metric, {String? exerciseMode}) {
  if (metric == 'timing_score') return 'Timing';
  if (metric == 'pitch_accuracy') return 'Pitch';
  if (metric == 'stability_score') return 'Stability';
  if (exerciseMode == 'breath') return 'Control';
  return 'Score';
}

Map<String, double> vocalRangeFrequencyBounds(String rangeName) {
  switch (rangeName.toLowerCase()) {
    case 'bass':
      return {'min': 82.0, 'max': 330.0}; // E2 to E4
    case 'baritone':
      return {'min': 98.0, 'max': 392.0}; // G2 to G4
    case 'tenor':
      return {'min': 130.0, 'max': 493.0}; // C3 to B4
    case 'alto':
      return {'min': 174.0, 'max': 698.0}; // F3 to F5
    case 'mezzo-soprano':
    case 'mezzo':
      return {'min': 220.0, 'max': 880.0}; // A3 to A5
    case 'soprano':
    default:
      return {'min': 261.63, 'max': 1046.50}; // C4 to C6
  }
}
