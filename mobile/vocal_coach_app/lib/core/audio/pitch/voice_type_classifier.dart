import 'dart:math' as math;

/// Vocal range categories based on standard choral classification.
///
/// Frequency ranges (comfortable singing range, not extremes):
/// - Soprano: C4 (261 Hz) – C6 (1047 Hz)
/// - Alto: F3 (175 Hz) – F5 (698 Hz)
/// - Tenor: C3 (131 Hz) – C5 (523 Hz)
/// - Baritone: A2 (110 Hz) – A4 (440 Hz)
/// - Bass: E2 (82 Hz) – E4 (330 Hz)
enum VoiceType {
  soprano,
  mezzoSoprano,
  alto,
  tenor,
  baritone,
  bass,
}

/// Result of voice type classification from pitch samples.
class VoiceTypeResult {
  const VoiceTypeResult({
    required this.voiceType,
    required this.confidence,
    required this.averageFrequencyHz,
    required this.lowestFrequencyHz,
    required this.highestFrequencyHz,
    required this.recommendedKey,
    required this.recommendedOctave,
    required this.sampleCount,
  });

  /// Detected voice type.
  final VoiceType voiceType;

  /// Confidence in the classification (0.0–1.0).
  final double confidence;

  /// Average voiced frequency during the calibration.
  final double averageFrequencyHz;

  /// Lowest detected pitch.
  final double lowestFrequencyHz;

  /// Highest detected pitch.
  final double highestFrequencyHz;

  /// Recommended starting key for exercises.
  final String recommendedKey;

  /// Recommended starting octave for exercises.
  final int recommendedOctave;

  /// Number of voiced samples used in classification.
  final int sampleCount;

  /// Human-readable label for the voice type.
  String get label {
    switch (voiceType) {
      case VoiceType.soprano:
        return 'Soprano';
      case VoiceType.mezzoSoprano:
        return 'Mezzo-Soprano';
      case VoiceType.alto:
        return 'Alto';
      case VoiceType.tenor:
        return 'Tenor';
      case VoiceType.baritone:
        return 'Baritone';
      case VoiceType.bass:
        return 'Bass';
    }
  }

  /// Short description of the vocal range for display.
  String get rangeDescription {
    final low = _frequencyToNoteName(lowestFrequencyHz);
    final high = _frequencyToNoteName(highestFrequencyHz);
    return '$low – $high';
  }
}

/// Classifies voice type from a collection of pitch frequency samples.
///
/// Designed for a calibration flow where the user sings a few notes
/// (comfortable range, not pushing limits). The classifier uses the
/// median pitch and comfortable range to determine voice type.
///
/// Usage:
/// ```dart
/// final classifier = VoiceTypeClassifier();
/// // Feed frequency samples from LiveAudioAnalyzer
/// for (final hz in voicedFrequencies) {
///   classifier.addSample(hz);
/// }
/// final result = classifier.classify();
/// ```
class VoiceTypeClassifier {
  final List<double> _samples = [];

  /// Minimum samples needed for a reliable classification.
  static const int minSamplesRequired = 20;

  /// Add a voiced frequency sample (Hz). Ignores non-positive values.
  void addSample(double frequencyHz) {
    if (frequencyHz > 0) {
      _samples.add(frequencyHz);
    }
  }

  /// Add multiple samples at once.
  void addSamples(Iterable<double> frequencies) {
    for (final hz in frequencies) {
      addSample(hz);
    }
  }

  /// Clear all collected samples.
  void reset() {
    _samples.clear();
  }

  /// Whether enough samples have been collected for classification.
  bool get hasEnoughSamples => _samples.length >= minSamplesRequired;

  /// Current sample count.
  int get sampleCount => _samples.length;

  /// Classify the voice type from collected samples.
  ///
  /// Returns null if insufficient samples (< [minSamplesRequired]).
  VoiceTypeResult? classify() {
    if (!hasEnoughSamples) return null;

    final sorted = List<double>.from(_samples)..sort();
    final count = sorted.length;

    // Use percentiles to ignore outliers.
    final p10Index = (count * 0.10).floor().clamp(0, count - 1);
    final p50Index = (count * 0.50).floor().clamp(0, count - 1);
    final p90Index = (count * 0.90).floor().clamp(0, count - 1);

    final lowFreq = sorted[p10Index];
    final medianFreq = sorted[p50Index];
    final highFreq = sorted[p90Index];

    // Average of the middle 80% for stability.
    var sum = 0.0;
    var middleCount = 0;
    for (var i = p10Index; i <= p90Index; i++) {
      sum += sorted[i];
      middleCount++;
    }
    final avgFreq = middleCount > 0 ? sum / middleCount : medianFreq;

    // Classify based on median frequency and range.
    final voiceType = _classifyFromMedian(medianFreq, lowFreq, highFreq);
    final confidence = _computeConfidence(medianFreq, lowFreq, highFreq, count);
    final recommendation = _recommendKeyAndOctave(voiceType, avgFreq);

    return VoiceTypeResult(
      voiceType: voiceType,
      confidence: confidence,
      averageFrequencyHz: avgFreq,
      lowestFrequencyHz: lowFreq,
      highestFrequencyHz: highFreq,
      recommendedKey: recommendation.key,
      recommendedOctave: recommendation.octave,
      sampleCount: count,
    );
  }

  /// Classification logic using median pitch as primary indicator.
  ///
  /// Boundary frequencies (median of comfortable range):
  /// Bass center:     ~100 Hz (E2–E4)
  /// Baritone center: ~150 Hz (A2–A4)
  /// Tenor center:    ~200 Hz (C3–C5)
  /// Alto center:     ~280 Hz (F3–F5)
  /// Mezzo center:    ~370 Hz (A3–A5)
  /// Soprano center:  ~500 Hz (C4–C6)
  VoiceType _classifyFromMedian(
    double medianHz,
    double lowHz,
    double highHz,
  ) {
    // Convert to MIDI note for easier comparison.
    final medianMidi = _frequencyToMidi(medianHz);
    final lowMidi = _frequencyToMidi(lowHz);

    // Primary classification by median pitch.
    if (medianMidi >= 72) {
      // C5 and above → Soprano
      return VoiceType.soprano;
    } else if (medianMidi >= 65) {
      // F4 and above → check if soprano or mezzo
      if (lowMidi >= 60) {
        return VoiceType.soprano;
      }
      return VoiceType.mezzoSoprano;
    } else if (medianMidi >= 60) {
      // C4 and above → Alto or Mezzo
      if (lowMidi >= 55) {
        return VoiceType.mezzoSoprano;
      }
      return VoiceType.alto;
    } else if (medianMidi >= 55) {
      // G3 and above → Alto or Tenor
      if (lowMidi >= 50) {
        return VoiceType.alto;
      }
      return VoiceType.tenor;
    } else if (medianMidi >= 48) {
      // C3 and above → Tenor
      return VoiceType.tenor;
    } else if (medianMidi >= 43) {
      // G2 and above → Baritone
      return VoiceType.baritone;
    } else {
      // Below G2 → Bass
      return VoiceType.bass;
    }
  }

  /// Confidence is higher when:
  /// - More samples are collected
  /// - The range isn't too wide (suggests consistent singing)
  /// - The median falls clearly within a voice type boundary
  double _computeConfidence(
    double medianHz,
    double lowHz,
    double highHz,
    int sampleCount,
  ) {
    // Sample count factor: ramps up from 0.5 at min to 1.0 at 100+ samples.
    final sampleFactor =
        (sampleCount / 100.0).clamp(0.5, 1.0);

    // Range consistency: narrower range = more confident.
    // Typical comfortable range is about 1 octave (factor of 2).
    final rangeRatio = highHz / lowHz.clamp(1.0, double.infinity);
    final rangeFactor = rangeRatio <= 2.5 ? 1.0 : (3.5 - rangeRatio).clamp(0.3, 1.0);

    // Distance from boundary: further from ambiguous zones = more confident.
    final medianMidi = _frequencyToMidi(medianHz);
    // Boundary MIDI notes: 43, 48, 55, 60, 65, 72
    const boundaries = [43.0, 48.0, 55.0, 60.0, 65.0, 72.0];
    var minDistance = 12.0; // max possible distance in our scheme
    for (final boundary in boundaries) {
      final dist = (medianMidi - boundary).abs();
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    // 0 distance from boundary = 0.5 confidence, 6+ semitones = 1.0.
    final boundaryFactor = (minDistance / 6.0).clamp(0.5, 1.0);

    return (sampleFactor * rangeFactor * boundaryFactor).clamp(0.0, 1.0);
  }

  /// Recommend a comfortable starting key and octave for the voice type.
  _KeyOctaveRecommendation _recommendKeyAndOctave(
    VoiceType voiceType,
    double avgFrequencyHz,
  ) {
    switch (voiceType) {
      case VoiceType.soprano:
        return const _KeyOctaveRecommendation(key: 'C', octave: 5);
      case VoiceType.mezzoSoprano:
        return const _KeyOctaveRecommendation(key: 'A', octave: 4);
      case VoiceType.alto:
        return const _KeyOctaveRecommendation(key: 'F', octave: 4);
      case VoiceType.tenor:
        return const _KeyOctaveRecommendation(key: 'C', octave: 4);
      case VoiceType.baritone:
        return const _KeyOctaveRecommendation(key: 'A', octave: 3);
      case VoiceType.bass:
        return const _KeyOctaveRecommendation(key: 'E', octave: 3);
    }
  }
}

class _KeyOctaveRecommendation {
  const _KeyOctaveRecommendation({
    required this.key,
    required this.octave,
  });

  final String key;
  final int octave;
}

/// Convert frequency (Hz) to MIDI note number.
/// A4 = 440 Hz = MIDI 69.
double _frequencyToMidi(double hz) {
  if (hz <= 0) return 0;
  return 69.0 + 12.0 * (math.log(hz / 440.0) / math.ln2);
}

/// Convert frequency to human-readable note name (e.g. "C4", "A3").
String _frequencyToNoteName(double hz) {
  if (hz <= 0) return '?';
  final midi = _frequencyToMidi(hz).round();
  const noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];
  final note = noteNames[midi % 12];
  final octave = (midi ~/ 12) - 1;
  return '$note$octave';
}
