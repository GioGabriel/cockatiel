import 'dart:math' as math;

/// A pitch estimate produced from one PCM frame.
class PitchEstimate {
  const PitchEstimate({required this.frequencyHz, required this.confidence});

  final double frequencyHz;
  final double confidence;
}

/// Lightweight YIN-style fundamental-frequency estimator.
///
/// The previous implementation selected an integer autocorrelation lag. That
/// made the estimate jump between bins and made harmonic-rich voices prone to
/// octave errors. This estimator uses the cumulative-mean-normalized
/// difference function and parabolic interpolation. It has no model download,
/// native dependency, or network requirement, so it is safe for live Chrome
/// and Android use.
class YinPitchEstimator {
  const YinPitchEstimator({
    required this.sampleRate,
    required this.minFrequencyHz,
    required this.maxFrequencyHz,
    this.threshold = 0.15,
    this.minConfidence = 0.55,
  });

  final int sampleRate;
  final int minFrequencyHz;
  final int maxFrequencyHz;
  final double threshold;
  final double minConfidence;

  PitchEstimate? estimate(List<int> frame) {
    if (frame.length < 32 || sampleRate <= 0) {
      return null;
    }

    final samples = List<double>.generate(
      frame.length,
      (index) => frame[index] / 32768.0,
      growable: false,
    );

    var mean = 0.0;
    for (final sample in samples) {
      mean += sample;
    }
    mean /= samples.length;

    var energy = 0.0;
    for (var index = 0; index < samples.length; index++) {
      final centered = samples[index] - mean;
      samples[index] = centered;
      energy += centered * centered;
    }
    if (energy / samples.length <= 1e-8) {
      return null;
    }

    final minLag = math.max(
      2,
      (sampleRate / maxFrequencyHz).floor(),
    );
    final maxLag = math.min(
      samples.length - 2,
      (sampleRate / minFrequencyHz).ceil(),
    );
    if (maxLag <= minLag) {
      return null;
    }

    final cumulativeMeanDifference = List<double>.filled(maxLag + 1, 1.0);
    var runningDifference = 0.0;
    for (var lag = 1; lag <= maxLag; lag++) {
      var difference = 0.0;
      final limit = samples.length - lag;
      for (var index = 0; index < limit; index++) {
        final delta = samples[index] - samples[index + lag];
        difference += delta * delta;
      }
      runningDifference += difference;
      cumulativeMeanDifference[lag] = runningDifference <= 1e-12
          ? 1.0
          : difference * lag / runningDifference;
    }

    var selectedLag = _firstThresholdTrough(
      cumulativeMeanDifference,
      minLag,
      maxLag,
    );
    if (selectedLag == null) {
      var fallbackLag = minLag;
      for (var lag = minLag + 1; lag <= maxLag; lag++) {
        if (cumulativeMeanDifference[lag] <
            cumulativeMeanDifference[fallbackLag]) {
          fallbackLag = lag;
        }
      }
      selectedLag = fallbackLag;
    }
    final chosenLag = selectedLag;

    final refinedLag = _parabolicMinimum(
      cumulativeMeanDifference,
      chosenLag,
    );
    if (refinedLag <= 0) {
      return null;
    }

    final frequencyHz = sampleRate / refinedLag;
    if (frequencyHz < minFrequencyHz || frequencyHz > maxFrequencyHz) {
      return null;
    }

    final confidence =
        (1.0 - cumulativeMeanDifference[chosenLag]).clamp(0.0, 1.0).toDouble();
    if (confidence < minConfidence) {
      return null;
    }

    return PitchEstimate(
      frequencyHz: frequencyHz,
      confidence: confidence,
    );
  }

  int? _firstThresholdTrough(
    List<double> values,
    int minLag,
    int maxLag,
  ) {
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (values[lag] > threshold) {
        continue;
      }
      var trough = lag;
      while (trough < maxLag && values[trough + 1] <= values[trough]) {
        trough += 1;
      }
      return trough;
    }
    return null;
  }

  double _parabolicMinimum(List<double> values, int lag) {
    if (lag <= 0 || lag >= values.length - 1) {
      return lag.toDouble();
    }
    final previous = values[lag - 1];
    final current = values[lag];
    final next = values[lag + 1];
    final denominator = previous - (2 * current) + next;
    if (denominator.abs() <= 1e-9) {
      return lag.toDouble();
    }
    final offset = 0.5 * (previous - next) / denominator;
    return (lag + offset).clamp(lag - 0.5, lag + 0.5).toDouble();
  }
}
