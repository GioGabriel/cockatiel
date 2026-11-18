import 'dart:math' as math;

/// Stabilizes visual pitch markers without modifying recorded scoring evidence.
/// Two nearby estimates establish a note; an isolated octave error cannot move
/// the marker to the opposite end of the meter. Silence clears it immediately.
class PitchDisplayFilter {
  double? _accepted;
  double? _pending;

  double? update(double? frequencyHz) {
    if (frequencyHz == null || !frequencyHz.isFinite || frequencyHz <= 0) {
      _accepted = null;
      _pending = null;
      return null;
    }
    bool nearby(double other) =>
        (1200 * math.log(frequencyHz / other) / math.ln2).abs() <= 80;
    if ((_accepted != null && nearby(_accepted!)) ||
        (_pending != null && nearby(_pending!))) {
      _accepted = frequencyHz;
      _pending = null;
    } else {
      _pending = frequencyHz;
    }
    return _accepted;
  }
}
