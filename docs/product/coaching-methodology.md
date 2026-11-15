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
2. For voice drills, optionally explore a comfortable starting note with the
   pre-drill warm-up; this is not a scored attempt.
3. Explain the goal and any unfamiliar terms.
4. Practice with local live pitch, timing, and waveform guidance.
5. Review understandable strengths and one or two improvements.
6. Recommend the next short practice and allow a repeat or recalibration.

## Pre-drill warm-up and starting-note explorer

The app offers a user-controlled warm-up before microphone-based drills. The
user can select `Do`, `Re`, `Mi`, `Fa`, `Sol`, and the optional extended octave
targets `La`, `Ti`, and high `Do`. Each target is resolved from the selected
movable-do key and octave, then shown with its chromatic note and frequency.

The user hums gently toward one target while the same deterministic live
guidance used by the drill reports signal quality, pitch direction, and stable
matching. The explorer has no timer-based pass/fail state; the user can stay on
one note, choose another, or start the drill. A visible stop action and safety
reminder prevent “open-ended” practice from becoming pressure to keep singing.

This is intentionally a coordination/readiness aid, not a claim that a short
warm-up expands range or identifies a formal voice type. The evidence and
limitations are recorded in [`warmup-evidence.md`](warmup-evidence.md).

## Why note sequences differ

The app does not treat every exercise as a scale lesson:

- The Basic Ladder teaches the five-note beginner foundation: `Do, Re, Mi, Fa, Sol`.
- A warm-up ladder now uses the same five notes so beginners do not see a
  misleading partial scale.
- Beginner resonance, warm-up, transition, and ladder exercises all present the
  complete `Do, Re, Mi, Fa, Sol` sequence before adding any return or control
  variation. This keeps the first lesson consistent with what a beginner
  expects from a five-note solfège ladder.
- Only the explicitly named Interval Jumps exercise intentionally skips notes,
  and its teaching note explains that the goal is accurate landing rather than
  scale memorization. Advanced transition practice still starts with the full
  five-note ladder before adding its control variation.

## Pacing and breathing boundaries

The old `beats` field is now an explainable allocation input, not a claim that
the phone is measuring musical beat accuracy. Runtime plans distribute the
requested duration across note windows and explicit rests. Beginner voice
patterns receive a larger rest interval after each target; intermediate and
advanced patterns receive shorter resets, and the final target has no forced
rest after it. A visible rest is a cue to relax and reset, not an instruction to
hold one breath through the ladder.

The 20/30/45-second attempt values remain product usability heuristics pending
calibration. The briefing screen also offers a slower pace, which expands the
guided block by 25%, and a beginner short-phrase option that uses `Do–Re–Mi`.
These controls are product pacing decisions, not medical or universal
vocal-duration prescriptions. Users should stop immediately if they feel strain,
dizziness, or discomfort.

The API returns this teaching purpose with every runtime pattern, and the
mobile briefing/session surfaces it before and during practice. This keeps a
pedagogical variation from looking like missing content.

The deterministic coaching logic engine remains authoritative for metric
interpretation. Google AI Studio may add a bounded natural-language summary, but it
does not replace the metrics or the local live feedback path.

## Audio privacy

Calibration and karaoke analyze microphone frames locally. Those flows persist
only numeric calibration metadata and session metrics; they do not upload or
retain a raw voice recording. The repository also contains a separate,
explicitly configured audio-snippet path with retention controls. Any use of
that path, or any future recording feature, must have explicit consent, a
retention policy, and a user-visible deletion path before it is enabled.
