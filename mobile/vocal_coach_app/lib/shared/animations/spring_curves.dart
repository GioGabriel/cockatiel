import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Custom spring simulation curve for natural-feeling animations.
///
/// Uses a damped harmonic oscillator formula:
/// position = 1 - e^(-damping * t) * cos(sqrt(stiffness) * t)
class SpringCurve extends Curve {
  const SpringCurve({
    this.damping = 0.85,
    this.stiffness = 200.0,
  });

  /// Controls how quickly oscillations decay. Higher = less bounce.
  final double damping;

  /// Controls the frequency of oscillation. Higher = faster spring.
  final double stiffness;

  @override
  double transformInternal(double t) {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;

    final double omega = math.sqrt(stiffness);
    final double decay = math.exp(-damping * t * 10.0);
    final double position = 1.0 - decay * math.cos(omega * t);

    return position.clamp(0.0, 1.0);
  }
}

/// Default spring curve for bottom sheets and modals.
const kDefaultSpringCurve = SpringCurve();
