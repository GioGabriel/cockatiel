import 'package:flutter/material.dart';

/// Displays a live coaching cue without reusing keys during overlapping
/// [AnimatedSwitcher] transitions.
///
/// A cue can legitimately change back to an earlier value before the previous
/// transition finishes (for example, when the microphone alternates between
/// "Listening" and a pitch cue). The revision key keeps the outgoing and
/// incoming children distinct while preserving the short fade animation.
class CoachStatusSwitcher extends StatefulWidget {
  const CoachStatusSwitcher({
    super.key,
    required this.status,
    this.style,
    this.duration = const Duration(milliseconds: 250),
  });

  final String status;
  final TextStyle? style;
  final Duration duration;

  @override
  State<CoachStatusSwitcher> createState() => _CoachStatusSwitcherState();
}

class _CoachStatusSwitcherState extends State<CoachStatusSwitcher> {
  int _statusRevision = 0;

  @override
  void didUpdateWidget(covariant CoachStatusSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _statusRevision += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      child: Text(
        widget.status,
        key: ValueKey<int>(_statusRevision),
        style: widget.style,
      ),
    );
  }
}
