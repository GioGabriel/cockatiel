import 'dart:math' as math;

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
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B'
];

const durationByDifficulty = {
  'beginner': 20,
  'intermediate': 30,
  'advanced': 45,
};

/// The movable-do labels used by every target, reference tone, and scorer.
/// This is a pentachord-to-octave vocabulary, not a claim that every beginner
/// exercise must use the full octave.
const List<String> canonicalSolfegeLabels = <String>[
  'Do',
  'Re',
  'Mi',
  'Fa',
  'Sol',
  'La',
  'Ti',
];

const Map<String, int> _keySemitoneOffsets = <String, int>{
  'C': 0,
  'CB': -1,
  'C#': 1,
  'DB': 1,
  'D': 2,
  'D#': 3,
  'EB': 3,
  'E': 4,
  'E#': 5,
  'FB': 4,
  'F': 5,
  'F#': 6,
  'GB': 6,
  'G': 7,
  'G#': 8,
  'AB': 8,
  'A': 9,
  'A#': 10,
  'BB': 10,
  'B': 11,
  'B#': 12,
};

const Map<String, int> _solfegeSemitoneOffsets = <String, int>{
  'do': 0,
  're': 2,
  'mi': 4,
  'fa': 5,
  'sol': 7,
  'so': 7,
  'la': 9,
  'ti': 11,
  'si': 11,
};

/// Resolves an absolute note (`C4`, `Db4`) or a movable-do label against a
/// key/octave. Numeric labels are accepted for karaoke pitch-map stages whose
/// source is already an absolute frequency. Unknown labels return null rather
/// than silently becoming the tonic, which would make the map and score lie in
/// different ways.
double? frequencyHzForPitchLabel(
  String label, {
  String key = 'C',
  int octave = 4,
}) {
  final normalizedLabel = label.trim();
  if (normalizedLabel.isEmpty) return null;

  final numericFrequency = double.tryParse(normalizedLabel);
  if (numericFrequency != null &&
      numericFrequency.isFinite &&
      numericFrequency > 0) {
    return numericFrequency;
  }

  final absoluteMatch = RegExp(
    r'^([A-Ga-g])([#b♯♭]?)(-?\d+)$',
    caseSensitive: false,
  ).firstMatch(normalizedLabel);
  if (absoluteMatch != null) {
    final letter = absoluteMatch.group(1)!.toUpperCase();
    final accidental = absoluteMatch.group(2)!;
    final octaveValue = int.tryParse(absoluteMatch.group(3)!);
    if (octaveValue == null) return null;
    final noteName = '$letter${switch (accidental) {
      '#' || '♯' => '#',
      'b' || 'B' || '♭' => 'B',
      _ => '',
    }}';
    final semitone = _keySemitoneOffsets[noteName.toUpperCase()];
    if (semitone == null) return null;
    return _frequencyForMidi((octaveValue + 1) * 12 + semitone);
  }

  var solfege = normalizedLabel.toLowerCase().replaceAll('′', "'");
  final isHigh = solfege.contains('high') || solfege.endsWith("'");
  solfege = solfege.replaceAll('high', '').replaceAll("'", '').trim();
  final scaleOffset = _solfegeSemitoneOffsets[solfege];
  if (scaleOffset == null) return null;

  final normalizedKey =
      key.trim().toUpperCase().replaceAll('♯', '#').replaceAll('♭', 'B');
  final tonicOffset = _keySemitoneOffsets[normalizedKey];
  if (tonicOffset == null) return null;
  final tonicMidi = (octave + 1) * 12 + tonicOffset;
  return _frequencyForMidi(tonicMidi + scaleOffset + (isHigh ? 12 : 0));
}

double _frequencyForMidi(int midiNote) {
  return 440.0 * math.pow(2.0, (midiNote - 69) / 12.0).toDouble();
}

/// Returns cents above/below target using the standard logarithmic pitch
/// relationship. Negative values mean the detected fundamental is low; positive
/// values mean it is high. Invalid frequencies are treated as unavailable and
/// return zero so callers can keep a numeric compatibility field while using a
/// separate measurability flag.
double centsErrorForFrequencies(double detectedHz, double targetHz) {
  if (!detectedHz.isFinite ||
      !targetHz.isFinite ||
      detectedHz <= 0 ||
      targetHz <= 0) {
    return 0;
  }
  return 1200 * (math.log(detectedHz / targetHz) / math.ln2);
}

/// Converts a measured fundamental to a chromatic display label.
String noteLabelForFrequency(double frequencyHz) {
  if (!frequencyHz.isFinite || frequencyHz <= 0) return 'unknown';
  final midi = (69 + 12 * (math.log(frequencyHz / 440) / math.ln2)).round();
  const names = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final nameIndex = midi % names.length;
  return '${names[nameIndex < 0 ? nameIndex + names.length : nameIndex]}${(midi ~/ 12) - 1}';
}

String displayMetricLabel(String metric, {String? exerciseMode}) {
  if (metric == 'timing_score') return 'Timing';
  if (metric == 'pitch_accuracy') return 'Pitch';
  if (metric == 'stability_score') return 'Stability';
  if (exerciseMode == 'breath') return 'Control';
  return 'Score';
}

Map<String, double> vocalRangeFrequencyBounds(String rangeName) {
  final normalized =
      rangeName.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  switch (normalized) {
    case 'bass':
      return {'min': 82.0, 'max': 330.0}; // E2 to E4
    case 'baritone':
      return {'min': 110.0, 'max': 440.0}; // A2 to A4
    case 'tenor':
      return {'min': 130.81, 'max': 523.25}; // C3 to C5
    case 'alto':
      return {'min': 174.0, 'max': 698.0}; // F3 to F5
    case 'mezzo-soprano':
    case 'mezzosoprano':
    case 'mezzo':
      return {'min': 220.0, 'max': 880.0}; // A3 to A5
    case 'soprano':
    default:
      return {'min': 261.63, 'max': 1046.50}; // C4 to C6
  }
}
