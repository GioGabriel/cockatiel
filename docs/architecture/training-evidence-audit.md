# Training evidence audit

Audit date: 2026-09-07

Scope: the seven exercises in `backend/vocal_coach_api/app/modules/training/catalog.py`, their runtime targets, mobile capture, deterministic scoring, and AI feedback context.

## Executive conclusion

The previous catalog was misleading. Do–Re–Mi–Fa–Sol is a valid five-note pentachord foundation for a beginner drill, but it is not the complete major scale. Movable-do solfège uses Do–Re–Mi–Fa–Sol–La–Ti–Do. The catalog now labels the five-note sequence as a foundation and expands intermediate and advanced ladder, sustain, and transition patterns through La, Ti, and high Do (`Do′`). Advanced interval work also samples the upper scale degrees.

Not every exercise needs every scale degree in every repetition. A warm-up or resonance task can use a comfortable subset to focus on onset, steadiness, or tone coordination. The progression must still expose the full octave at higher levels, and the app must not imply that stopping at Sol is a complete scale.

## Exercise-by-exercise audit

| Exercise | Defensible training purpose | Evidence captured by the app | Important boundary |
| --- | --- | --- | --- |
| Resonance Placement | Gentle humming/semi-occluded work and sustained vowels provide a repeatable coordination task. | F0/cents error, voiced coverage, onset delay, settling time, pitch variation, loudness consistency, and acoustic descriptors. | A phone mic cannot directly measure vocal-tract resonance, throat tension, airflow, or vocal-fold health. “Resonance” is an acoustic proxy here. |
| Pitch Warmup | Gentle progressive pitch targets provide a low-load pitch-centering routine. | Pitch error, confident coverage, onset/timing, settling, stability, loudness, and stream quality. | The app cannot decide whether a warm-up is physiologically safe for a specific person or diagnose strain. |
| Note Transition Drill | Stepwise legato and progressively wider movement isolate pitch transitions and settling. | Target interval, cents error, onset delay, settling time, transition completion/failure, and per-target coverage. | Acoustic movement is not a direct observation of laryngeal motion or tension. |
| Basic Ladder | Movable-do scale-degree mapping; Do–Sol is a beginner pentachord, followed by full-octave exposure. | Per-note pitch, timing, onset, settling, stability, confidence, and acoustic evidence. | A score on one guided key/pattern does not prove general aural skill. |
| Interval Jumps | Non-adjacent targets train anticipation and direct landing instead of only stepwise sliding. | Interval landing error, onset/settling, transition recovery, and target stability. | The detector cannot know whether the singer internally heard the next note before singing. |
| Support Ladder | Paced inhale/settle/exhale phases rehearse timing and body-awareness habits. | Timer phase completion and interruptions; optional microphone audible coverage/loudness proxy. | A phone mic does not measure airflow, lung volume, rib motion, or subglottal pressure. |
| Long Phrase Breathing | Longer paced releases rehearse phrase planning and endurance timing. | Phase completion, interruptions, cycle consistency, and optional audio proxy. | There is no universal “correct” respiratory pattern; this is not respiratory therapy or a clinical test. |

## What the score means

The deterministic score is an engineering measurement of the selected recording against the selected target pattern:

- Pitch accuracy uses fundamental-frequency error in cents, target coverage, and confidence.
- Timing accuracy now measures target-window coverage plus target entry delay. It is not the pitch-hit percentage relabeled as timing.
- Pitch stability uses the spread of cents error around the singer’s measured center.
- Transition smoothness uses the time and pitch error required to settle after a guided target change.
- Vibrato is reported only when periodic modulation is observed; a straight tone remains neutral rather than being punished.
- “Breath control” in voice drills is explicitly a continuity/loudness proxy. Timer breathing scores are phase and pacing scores; optional mic data is descriptive only.
- Zero or low metrics are reported as “not measurable” when there is no target, no confident voiced evidence, or an unavailable stream. Gemini may explain the evidence, but it cannot invent a measurement that was not captured.

The additional acoustic fields (zero-crossing rate, spectral centroid, spectral rolloff, crest factor, clipping ratio, and pitch periodicity) are recorded as evidence but are not yet allowed to change the user’s score. They need golden recordings and human-rated calibration first; otherwise they would create false precision.

## Research basis

The implementation is informed by the following sources, while avoiding clinical claims:

- Solfège and full major-scale syllables: [University of Utah Pressbooks, Foundations of Aural Skills — Solfège](https://uen.pressbooks.pub/auralskills/chapter/solfege/).
- Objective singing accuracy and expert ratings: [Larrouy-Maestri et al., The Evaluation of Singing Voice Accuracy](https://orbi.uliege.be/bitstream/2268/137770/1/Larrouy-Maestri%2C%20L%C3%A9v%C3%AAque%2C%20Sch%C3%B6n%2C%20Giovanni%2C%20Morsomme%2C%20JV.pdf).
- Pitch inaccuracy in singing and effects of training/feedback: [Bottalico et al., Pitch Inaccuracy](https://pmc.ncbi.nlm.nih.gov/articles/PMC5010534/).
- Visual and auditory feedback for pitch matching: [Blanco et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC8297736/).
- Interval accuracy and vibrato as singing-skill features: [Nakano et al., Interspeech 2006](https://www.isca-archive.org/interspeech_2006/nakano06_interspeech.html).
- Semi-occluded vocal-tract warm-up work: [Immediate Effects of Semi-occluded Vocal Tract Exercises](https://www.sciencedirect.com/science/article/pii/S0892199721001831) and [Vocal Function Exercises with and without Semi-occlusion](https://pmc.ncbi.nlm.nih.gov/articles/PMC6207476/).
- Singing respiratory kinematics and variability: [Breathing and Singing](https://pmc.ncbi.nlm.nih.gov/articles/PMC4861272/).
- Sensor-based breath tutoring, demonstrating the need for pressure sensing when measuring breath: [Sensing the Breath](https://arxiv.org/abs/2202.01439).
- Fundamental-frequency detection: [YIN](https://pubmed.ncbi.nlm.nih.gov/12002874/).

## Remaining calibration work

This audit makes the product honest and more measurable; it does not make the score clinically validated. The next evidence gate is a versioned fixture set containing clean, noisy, late-onset, pitch-drifting, interval-jump, straight-tone, and vibrato recordings with human labels. The score formulas should then be calibrated against those labels and checked for microphone/device bias before any acoustic descriptor is promoted into the score.

## Decision ledger: evidence, applicability, and product boundary

| Product decision | Source and evidence strength | Applicable product claim | What the phone can measure | What it cannot establish | Classification |
| --- | --- | --- | --- | --- | --- |
| Keep Do–Re–Mi–Fa–Sol as the beginner foundation and label the full octave separately. | [University of Utah Pressbooks — Solfège](https://uen.pressbooks.pub/auralskills/chapter/solfege/), an established aural-skills reference; it supports the movable-do syllable sequence, not a particular lesson duration. | A five-note pentachord is a reasonable introductory scope when it is clearly not called the whole major scale. | Target-note matching and interval relationships for the selected key/octave. | General musicianship, transfer to songs, or an individual’s comfortable range. | Supported curriculum decision; beginner scope remains a product choice. |
| Add visual and auditory target feedback, but keep it specific and debounced. | [Bottalico et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC5010534/), [Berglin, Pfordresher, and Demorest](https://journals.sagepub.com/doi/10.1177/03057356211026730), and [Blanco et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC8297736/) support the relevance of external feedback for pitch matching/remediation; their populations and protocols do not validate this app’s thresholds. | “A little higher,” “On target,” and evidence-specific correction can help a learner act on the next note. | Current cents direction, confidence, signal quality, and recent stability. | Learning outcome, vocal effort, tension, or “perfect” performance from one frame. | Supported feedback principle; thresholds are provisional engineering heuristics. |
| Use YIN-style pitch tracking for the live path. | [de Cheveigné and Kawahara — YIN](https://pubmed.ncbi.nlm.nih.gov/12002874/), a foundational F0-estimation method; real microphone conditions still create octave, noise, and breathy-input errors. | Cents error is a transparent, reproducible pitch-distance measure. | Fundamental-frequency estimate, confidence, voiced coverage, and cents error. | True perceived pitch in every noisy/breathy frame, timbre quality, or vocal health. | Supported algorithm choice; device calibration remains required. |
| Keep voice “breath control” as a continuity/loudness proxy and breathing drills as timer evidence. | [Breathing and Singing — Objective Respiratory Characterization](https://pmc.ncbi.nlm.nih.gov/articles/PMC4861272/) shows that singing respiration involves physiological variables beyond an audio signal. | Explain continuity and loudness only; never call it airflow or breath-support measurement. | Audible coverage, voiced runs, loudness variation, phase completion, interruptions, and pacing. | Airflow, lung capacity, pressure, rib motion, vocal-fold health, or clinical respiratory safety. | Supported limitation; all breathing durations remain usability heuristics. |
| Retain gentle semi-occluded/humming-style exercises as optional coordination practice. | [Effects of Semi-Occluded Vocal Tract Training in Adult Choir Singers](https://pubmed.ncbi.nlm.nih.gov/41896048/) is relevant to the exercise family, but does not validate this app’s exact routine or scoring. | A gentle warm-up can be offered without claiming guaranteed resonance or injury prevention. | Pitch, continuity, and acoustic descriptors during the exercise. | Resonance placement, tension, vocal-fold loading, or therapeutic benefit. | Supported exercise rationale; app-specific dose and score are provisional. |
| Keep 20/30/45-second durations and 50/100-cent scoring cutoffs explicitly labeled as provisional. | No cited source validates these exact constants for all beginners, voices, devices, or tasks. | Use them as short repeatable product defaults with rests, stop controls, and later calibration. | Observed target windows, onset delay, coverage, and cents error. | A universal safe breath duration, formal skill level, or clinical outcome. | Product usability / engineering heuristic requiring calibration. |

### Curriculum decision

Beginner training remains pentachord-based because the narrower range reduces the
first lesson’s cognitive and vocal load while preserving a clear scale-degree
foundation. It is now labeled “five-note beginner foundation,” not “full scale.”
Intermediate and advanced ladder/transition patterns expose La, Ti, and high Do;
the full major-scale movable-do sequence is `Do, Re, Mi, Fa, Sol, La, Ti, Do`.
The runtime adds explicit rests after beginner targets and exposes target windows,
rest intervals, and breath cues. This means a user can reset between notes rather
than being forced to sustain the entire ladder on one breath. The briefing screen
now exposes a slower pace (a 25% longer guided block) and a beginner short-phrase
mode (the first three targets, `Do–Re–Mi`) for repeatable breath resets. These are
product pacing controls, not claims about a universal safe tempo or breath pattern.
