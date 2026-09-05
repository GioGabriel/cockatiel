# Coaching methodology

## Guided practice blocks

Tutorial exercises use short, repeatable blocks rather than forcing a beginner to
hold attention for a full minute before receiving feedback:

- Beginner: 20 seconds — enough time to understand one target without vocal or
  cognitive fatigue.
- Intermediate: 30 seconds — enough repetition to observe consistency while
  keeping the exercise easy to repeat.
- Advanced: 45 seconds — enough phrase time for transitions and control without
  turning a tutorial into a full-song performance.

These values are the shared attempt policy in the backend training catalog and
are mirrored by the Flutter briefing/session fallbacks. A user can repeat or
continue instead of being locked into one long take. Karaoke duration remains a
separate content value because a song is a performance activity, not a tutorial
block.

## Lesson flow

Each guided exercise should make the same sequence visible to the user:

1. Prepare and check the microphone when needed.
2. Explain the goal and any unfamiliar terms.
3. Practice with local live pitch, timing, and waveform guidance.
4. Review understandable strengths and one or two improvements.
5. Recommend the next short practice and allow a repeat or recalibration.

The deterministic coaching logic engine remains authoritative for metric
interpretation. OpenRouter may add a bounded natural-language summary, but it
does not replace the metrics or the local live feedback path.

## Audio privacy

Calibration and karaoke analyze microphone frames locally. Those flows persist
only numeric calibration metadata and session metrics; they do not upload or
retain a raw voice recording. The repository also contains a separate,
explicitly configured audio-snippet path with retention controls. Any use of
that path, or any future recording feature, must have explicit consent, a
retention policy, and a user-visible deletion path before it is enabled.
