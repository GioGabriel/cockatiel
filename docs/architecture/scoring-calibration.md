# Vocal scoring calibration and evidence policy

## Status

Scoring version `2.0` is deterministic and reproducible. It is designed for
coaching feedback and practice progress, not clinical diagnosis, audition
certification, or a claim that a single recording measures a singer's complete
ability.

## Runtime pipeline

1. The Flutter client captures mono PCM microphone frames locally.
2. A YIN-style fundamental-frequency estimator removes DC offset, searches the
   configured vocal range, uses cumulative-mean-normalized differences, and
   interpolates the selected lag between samples.
3. Frames below the confidence threshold are treated as missing voice evidence.
4. `VocalMetricAccumulator` is the shared scorer for guided training and
   karaoke. It uses timestamps, target pitch, confidence, loudness consistency,
   voiced coverage, pitch error, target transitions, and stream gaps.
5. The backend applies exercise-specific weights and thresholds. It is the
   authority for the saved numeric score and selects the best valid attempt.

The client does not use a language model to calculate a score. Google AI Studio,
when configured, can only write the bounded natural-language summary.
Deterministic strengths, improvements, next exercises, and the numeric score
remain available when it is disabled or unreachable.

## Evidence gates

- Fewer than 16 voice frames cannot be saved as a scored attempt. This prevents
  a near-empty microphone capture from receiving a misleading high score.
- Fewer than 128 frames is marked `limited` evidence in the backend score
  breakdown. At or above 128 frames is marked `reliable` for product display;
  this is an engineering confidence label, not a statistical confidence
  interval.
- Missing target-guide frames cannot create pitch or timing accuracy.
- Stream gaps are counted as missing evidence rather than silently ignored.
- A clean sustained note scores highly only when it is both voiced and close to
  its target. Silence, low confidence, detuning, and incomplete coverage lower
  the result.

## What the metrics mean

- **Pitch accuracy:** confidence-weighted target error using a smooth penalty
  that reaches zero at a one-semitone error, then reduced by target coverage.
- **Timing accuracy:** target-following coverage. It is not yet beat-level onset
  accuracy because the current runtime contract does not send beat/onset labels
  to the scorer.
- **Breath control:** a microphone proxy made from voiced coverage, sustained
  continuity, and loudness consistency. It is not a respiratory measurement.
- **Pitch stability:** variation of target-relative cents error after separating
  the average offset from the fluctuation.
- **Vibrato consistency:** a conservative estimate using oscillation amplitude,
  rate, and regularity. When no vibrato is observable, the metric stays neutral
  rather than calling the singer's technique a failure.
- **Note-transition smoothness:** settling time and landing accuracy after a
  material target-pitch change.

## Calibration boundary

The current implementation is materially stronger than an integer-lag average,
but the constants are still engineering defaults. To claim calibrated scoring,
the project needs a consented, licensed evaluation set containing:

- clean synthetic tones and controlled cents offsets;
- sustained vowels, consonant-heavy phrases, vibrato, slides, registers, and
  intentional silence;
- multiple voice types, microphones, rooms, background-noise levels, and
  Android/Chrome capture paths;
- expert annotations for pitch center, onset/offset, breath phrasing, and
  transition quality.

The calibration process should freeze a versioned fixture set, compare pitch
error in cents and frame-level voiced/unvoiced decisions, measure test-retest
reliability, report errors by device and voice group, and only then tune weights
or thresholds. Until that exists, score trends within one user's device and
exercise are more defensible than comparing users or making clinical claims.

## Research and implementation choices

- [librosa pYIN documentation](https://librosa.org/doc/0.11.0/generated/librosa.pyin.html)
  documents probabilistic YIN candidate selection and Viterbi tracking. A
  server-side batch evaluator can use pYIN later if the product receives
  consented audio uploads; the live Flutter path intentionally avoids a heavy
  model/runtime dependency.
- [torchcrepe](https://github.com/maxrmorrison/torchcrepe) is a strong MIT-
  licensed neural pitch-tracking option for offline/batch experiments, but its
  PyTorch/model footprint is not appropriate for the current live mobile path.
- [Essentia licensing](https://essentia.upf.edu/licensing_information.html)
  must be reviewed before using it in a distributed commercial product; its
  open license and model licenses are not automatically a production-safe
  substitute.

## Free narrative AI decision

No free hosted model should be made authoritative for numeric scoring. Current
options have material tradeoffs:

- Google AI Studio's Gemini models have a free developer tier and structured JSON
  output, but quotas, regional availability, data-use terms, and account
  configuration must be verified before production use.
- Ollama is free for local/self-hosted inference and has an OpenAI-compatible
  endpoint, but it requires a managed machine and model-license review; it is
  not a drop-in free Render capability.

The product therefore keeps deterministic feedback as the default and treats
Google AI Studio narrative generation as an optional adapter. This gives the
app a dependable result even when the provider is unavailable.

The Google documentation states that rate limits are applied per project, not
per API key. Multiple comma-separated keys are therefore a resilience measure
for separate projects or independently restricted keys, not a way to multiply
one project's quota.
