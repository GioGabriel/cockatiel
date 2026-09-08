/// Plain-language live guidance for singing targets.
///
/// This deliberately separates signal quality from pitch direction. A phone
/// microphone cannot tell a singer that they used "too much" breath or
/// tension, so every cue names the observable condition that supports it.
enum LivePitchCue {
  startWhenReady,
  noClearNote,
  tooQuiet,
  tooLoud,
  tooLow,
  tooHigh,
  onTarget,
  holdSteady,
  takeBreath,
}

class LivePitchGuidance {
  const LivePitchGuidance({
    required this.cue,
    required this.centsError,
    required this.confidence,
  });

  final LivePitchCue cue;
  final double centsError;
  final double confidence;

  String get message => switch (cue) {
        LivePitchCue.startWhenReady => 'Start when you’re ready',
        LivePitchCue.noClearNote => 'I can’t hear a clear note yet',
        LivePitchCue.tooQuiet => 'Too quiet to measure reliably',
        LivePitchCue.tooLoud => 'Too loud or clipping',
        LivePitchCue.tooLow => 'A little higher',
        LivePitchCue.tooHigh => 'A little lower',
        LivePitchCue.onTarget => 'On target',
        LivePitchCue.holdSteady => 'Hold steady',
        LivePitchCue.takeBreath => 'Take a relaxed breath before the next note',
      };
}

/// Debounces live cues and keeps the on-target window from flickering at its
/// boundary. The controller is intentionally small and deterministic so it
/// can be tested without a microphone or widget tree.
class LivePitchGuidanceController {
  LivePitchGuidanceController({
    this.requiredStableFrames = 2,
    this.onTargetEnterCents = 30,
    this.onTargetExitCents = 36,
    this.quietFloorDb = -50,
    this.clippingRatioThreshold = 0.08,
  }) : _current = const LivePitchGuidance(
          cue: LivePitchCue.startWhenReady,
          centsError: 0,
          confidence: 0,
        );

  final int requiredStableFrames;
  final double onTargetEnterCents;
  final double onTargetExitCents;
  final double quietFloorDb;
  final double clippingRatioThreshold;

  LivePitchGuidance _current;
  LivePitchCue? _candidateCue;
  int _candidateFrames = 0;
  final List<double> _recentCents = <double>[];
  bool _lastFrameMeasurable = false;

  LivePitchGuidance get current => _current;

  /// True only when the current cue is backed by a voiced, target-relative
  /// estimate. Signal-quality cues must not place a pitch marker on the map.
  bool get isMeasurable => switch (_current.cue) {
        LivePitchCue.tooLow ||
        LivePitchCue.tooHigh ||
        LivePitchCue.onTarget ||
        LivePitchCue.holdSteady =>
          true,
        _ => false,
      };

  /// Whether the latest frame passed the signal and pitch gates. This is kept
  /// separate from [isMeasurable], whose cue can remain debounced for clarity.
  bool get lastFrameMeasurable => _lastFrameMeasurable;

  void reset() {
    _candidateCue = null;
    _candidateFrames = 0;
    _recentCents.clear();
    _lastFrameMeasurable = false;
    _current = const LivePitchGuidance(
      cue: LivePitchCue.startWhenReady,
      centsError: 0,
      confidence: 0,
    );
  }

  LivePitchGuidance update({
    required bool isAttemptRunning,
    required bool hasTarget,
    required bool voiced,
    required double confidence,
    required double loudnessDb,
    required double centsError,
    double clippingRatio = 0,
    double? quietFloorDb,
  }) {
    final safeConfidence =
        confidence.isFinite ? confidence.clamp(0.0, 1.0).toDouble() : 0.0;
    final safeCents = centsError.isFinite ? centsError : 0.0;
    final safeLoudness = loudnessDb.isFinite ? loudnessDb : -double.infinity;
    final safeClipping =
        clippingRatio.isFinite ? clippingRatio.clamp(0.0, 1.0) : 1.0;
    final nextCue = _classify(
      isAttemptRunning: isAttemptRunning,
      hasTarget: hasTarget,
      voiced: voiced,
      confidence: safeConfidence,
      loudnessDb: safeLoudness,
      centsError: safeCents,
      clippingRatio: safeClipping.toDouble(),
      quietFloorDb: quietFloorDb ?? this.quietFloorDb,
    );
    _lastFrameMeasurable = nextCue == LivePitchCue.tooLow ||
        nextCue == LivePitchCue.tooHigh ||
        nextCue == LivePitchCue.onTarget ||
        nextCue == LivePitchCue.holdSteady;
    final cue = _debounce(nextCue);
    _current = LivePitchGuidance(
      cue: cue,
      centsError: safeCents,
      confidence: safeConfidence,
    );
    return _current;
  }

  LivePitchCue _classify({
    required bool isAttemptRunning,
    required bool hasTarget,
    required bool voiced,
    required double confidence,
    required double loudnessDb,
    required double centsError,
    required double clippingRatio,
    required double quietFloorDb,
  }) {
    if (!isAttemptRunning) return LivePitchCue.startWhenReady;
    if (!hasTarget) return LivePitchCue.takeBreath;
    if (clippingRatio >= clippingRatioThreshold || loudnessDb >= -2) {
      return LivePitchCue.tooLoud;
    }
    if (loudnessDb <= quietFloorDb) {
      return LivePitchCue.tooQuiet;
    }
    if (!voiced || confidence < 0.45) {
      return LivePitchCue.noClearNote;
    }

    // A large correction is a new settling window; do not let the previous
    // low/high state make the first centered frames look unstable.
    if (_recentCents.isNotEmpty &&
        (centsError - _recentCents.last).abs() > onTargetExitCents) {
      _recentCents.clear();
    }
    _recentCents.add(centsError);
    if (_recentCents.length > 6) {
      _recentCents.removeAt(0);
    }
    final range = _recentCents.isEmpty
        ? 0.0
        : _recentCents.reduce((a, b) => a > b ? a : b) -
            _recentCents.reduce((a, b) => a < b ? a : b);
    final targetBoundary = _current.cue == LivePitchCue.onTarget
        ? onTargetExitCents
        : onTargetEnterCents;
    if (centsError.abs() <= targetBoundary) {
      return range > 45 ? LivePitchCue.holdSteady : LivePitchCue.onTarget;
    }
    return centsError < 0 ? LivePitchCue.tooLow : LivePitchCue.tooHigh;
  }

  LivePitchCue _debounce(LivePitchCue nextCue) {
    if (nextCue == _current.cue) {
      _candidateCue = null;
      _candidateFrames = 0;
      return nextCue;
    }
    if (_candidateCue != nextCue) {
      _candidateCue = nextCue;
      _candidateFrames = 1;
    } else {
      _candidateFrames += 1;
    }
    if (_candidateFrames >= requiredStableFrames ||
        nextCue == LivePitchCue.tooQuiet ||
        nextCue == LivePitchCue.tooLoud ||
        nextCue == LivePitchCue.takeBreath) {
      _candidateCue = null;
      _candidateFrames = 0;
      return nextCue;
    }
    return _current.cue;
  }
}
