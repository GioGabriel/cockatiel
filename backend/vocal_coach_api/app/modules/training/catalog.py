from copy import deepcopy
from typing import Any

DifficultyLevel = str

_DEFAULT_ATTEMPT_POLICY = {
  "max_attempts": 3,
  "duration_sec_by_difficulty": {
    "beginner": 20,
    "intermediate": 30,
    "advanced": 45,
  },
}

_DEFAULT_METRIC_WEIGHTS = {
  "pitch_accuracy": 0.2,
  "timing_accuracy": 0.15,
  "breath_control": 0.2,
  "pitch_stability": 0.2,
  "vibrato_consistency": 0.1,
  "note_transition_smoothness": 0.15,
}

_PATTERN_TEACHING_NOTES = {
  "ladder": "A five-note pentachord (Do, Re, Mi, Fa, Sol) is the beginner foundation; higher levels add La, Ti, and high Do for the full octave.",
  "sustain": "A five-note pentachord (Do, Re, Mi, Fa, Sol) is the beginner foundation; higher levels add La, Ti, and high Do for the full octave.",
  "transition": "This is a connection exercise: repeated or nearby notes build smooth movement between pitches.",
  "jump": "This is an interval exercise: the notes intentionally skip steps so you can practice accurate leaps.",
  "breathing": "This is a breathing exercise: follow the inhale and exhale phases instead of singing a note sequence.",
}

_FULL_SCALE = ("Do", "Re", "Mi", "Fa", "Sol", "La", "Ti", "Do′")

_TRAINING_EVIDENCE_METADATA: dict[str, dict[str, list[str]]] = {
  "resonance_placement": {
    "training_basis": [
      "Humming and other semi-occluded vocal-tract exercises are used as gentle warm-up and coordination tasks.",
      "Sustained vowels make pitch steadiness and repeatable tone easier to observe.",
    ],
    "measurement_plan": [
      "Fundamental frequency (pitch) error in cents against each target note.",
      "Voiced coverage, onset delay, pitch settling time, and pitch variation per target.",
      "Relative loudness consistency and additional microphone acoustic descriptors when available.",
    ],
    "measurement_limits": [
      "A phone microphone cannot directly measure vocal-tract resonance, throat tension, or airflow.",
      "Resonance and breath-control feedback is an acoustic proxy, not a clinical voice assessment.",
    ],
  },
  "warmup_pitch": {
    "training_basis": [
      "Gentle, progressively wider pitch patterns are a practical way to prepare pitch coordination without forcing volume.",
      "Short repeated targets provide immediate external feedback while keeping practice blocks repeatable.",
    ],
    "measurement_plan": [
      "Pitch error in cents, target-note coverage, and confident voiced-frame coverage.",
      "Onset delay, pitch settling time, pitch variability, and loudness consistency per note.",
    ],
    "measurement_limits": [
      "This does not verify vocal-fold health, range safety, or absence of strain.",
      "The pitch detector can be less reliable with noise, breathy tone, very low volume, or overlapping sound.",
    ],
  },
  "note_transition_drill": {
    "training_basis": [
      "Adjacent-note legato work isolates the coordination needed to move between pitches without an uncontrolled slide.",
      "Progressing from steps to a wider octave exposes both small transitions and larger register changes.",
    ],
    "measurement_plan": [
      "Target-to-target interval, onset delay, pitch settling time, and cents error after each transition.",
      "Completed versus failed transitions, voiced coverage, and pitch stability for each target window.",
    ],
    "measurement_limits": [
      "The app estimates acoustic pitch movement; it does not see laryngeal motion or diagnose vocal tension.",
      "Transition scores need calibrated recordings before they should be interpreted as a proficiency grade.",
    ],
  },
  "do_re_mi_basic_ladder": {
    "training_basis": [
      "Movable-do solfège links scale-degree hearing to the voice; Do–Sol is a useful beginner pentachord before the full octave.",
      "Intermediate and advanced levels add La, Ti, and high Do so the progression does not stop at Sol.",
    ],
    "measurement_plan": [
      "Per-note cents error, on-target rate, onset timing, settling time, and pitch stability.",
      "Coverage and confidence are reported so a missing or noisy recording cannot look like a perfect score.",
    ],
    "measurement_limits": [
      "The drill measures matching to the selected tonic and target notes; it does not prove aural skill outside this pattern.",
      "A numeric score is an engineering measure and still needs human-rated calibration for proficiency claims.",
    ],
  },
  "do_re_mi_interval_jumps": {
    "training_basis": [
      "Non-adjacent scale-degree jumps train anticipation and direct landing rather than relying only on stepwise sliding.",
      "The advanced pattern samples La, Ti, and high Do so interval work covers the full octave.",
    ],
    "measurement_plan": [
      "Interval size, landing error in cents, onset delay, settling time, and post-landing stability.",
      "Transition completion rate and recovery time after each guided jump.",
    ],
    "measurement_limits": [
      "The detector cannot determine whether a singer internally heard the note before singing it.",
      "Large jumps can exceed the configured vocal range; practice range must remain comfortable for the singer.",
    ],
  },
  "breath_support_ladder": {
    "training_basis": [
      "Paced inhale, settle, and exhale phases build repeatable breath timing and body-awareness habits.",
      "The routine is a coordination exercise, not a claim that one breathing pattern fits every singer.",
    ],
    "measurement_plan": [
      "Phase completion, interruptions, elapsed duration, and consistency of following the guided sequence.",
      "Optional microphone audio proxy: audible-frame coverage, loudness trend, and stream quality.",
    ],
    "measurement_limits": [
      "A phone microphone cannot measure airflow, lung volume, rib movement, subglottal pressure, or true breath support.",
      "Audio evidence is optional and cannot replace respiratory or airflow sensors.",
    ],
  },
  "long_phrase_breathing": {
    "training_basis": [
      "Longer paced exhale phases rehearse planning and endurance for phrase-length timing.",
      "Professional breathing is variable; the routine is a repeatable practice target, not a universal physiological prescription.",
    ],
    "measurement_plan": [
      "Phase completion, interruption count, time spent in each guided phase, and cycle consistency.",
      "Optional microphone audio proxy: audible-frame coverage, loudness trend, and stream quality.",
    ],
    "measurement_limits": [
      "A phone microphone cannot prove airflow pacing or respiratory kinematics.",
      "Stop if dizzy, uncomfortable, or strained; this app is not medical or respiratory therapy.",
    ],
  },
}


def _stage(
  stage_id: str,
  *,
  title: str,
  solfege: str,
  instruction: str,
  beats: int,
) -> dict[str, Any]:
  return {
    "stage_id": stage_id,
    "title": title,
    "target_label": solfege,
    "solfege": solfege,
    "instruction": instruction,
    "beats": beats,
  }


def _pattern(
  pattern_id: str,
  *,
  pattern_type: str,
  summary: str,
  stages: list[dict[str, Any]],
  teaching_note: str | None = None,
) -> dict[str, Any]:
  return {
    "pattern_id": pattern_id,
    "pattern_type": pattern_type,
    "summary": summary,
    "teaching_note": teaching_note or _PATTERN_TEACHING_NOTES.get(
      pattern_type,
      "Follow the guided steps and use the live cue as your next action.",
    ),
    "stages": stages,
  }


# Scope: Thesis-documented categories only (Vocal Training, Do Re Mi Pitch, Breathing Exercises).
# Sprint 11 features (diction, pronunciation, phrase clarity) are excluded per Requirements 9.1, 9.4.
_VOCAL_COACH_CATALOG: dict[str, Any] = {
  "module_id": "vocal_coach",
  "title": "Vocal Coach",
  "subtitle": "Structured, AI-guided vocal development",
  "description": "Practice targeted drills with real-time guidance and async AI feedback.",
  "attempt_policy": deepcopy(_DEFAULT_ATTEMPT_POLICY),
  "categories": [
    {
      "category_id": "vocal_training",
      "title": "Vocal Training",
      "subtitle": "Tone, placement, control, and transitions",
      "description": "Core vocal technique drills for stable and expressive singing.",
      "exercises": [
        {
          "exercise_id": "resonance_placement",
          "name": "Resonance Placement",
          "description": "Place tone forward while keeping neck and jaw relaxed.",
          "objective": "Practice a stable, forward-feeling tone without adding throat tension.",
          "what_you_do": "Hum and sustain light notes while keeping the tone bright, relaxed, and easy to observe.",
          "requires_microphone": True,
          "exercise_mode": "voice",
          "instructions": [
            "Stand tall and relaxed.",
            "Sustain open vowels with an even, comfortable tone.",
            "Keep tone bright without throat squeeze.",
          ],
          "ai_focus": "Tone consistency, projection efficiency, and resonance stability",
          "default_difficulty": "beginner",
          "recommended_order": 1,
          "focus_metrics": ["breath_control", "pitch_stability", "pitch_accuracy"],
          "metric_weights": {
            "pitch_accuracy": 0.2,
            "timing_accuracy": 0.1,
            "breath_control": 0.3,
            "pitch_stability": 0.25,
            "vibrato_consistency": 0.05,
            "note_transition_smoothness": 0.1,
          },
          "success_thresholds": {
            "overall_score": 75,
            "metric_floors": {
              "breath_control": 72,
              "pitch_stability": 68,
            },
          },
          "coach_cues": {
            "ready": "Keep the tone forward and the throat easy.",
            "too_soft": "Use a clear, comfortable sound without pushing the throat.",
            "on_pitch": "Bright and steady - keep the buzz forward.",
            "low_pitch": "Lift resonance slightly without adding tension.",
            "high_pitch": "Release jaw pressure and let the tone settle.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "placement_foundation",
              pattern_type="sustain",
              summary="Five relaxed tones that build forward placement across the complete beginner sequence.",
              teaching_note="This beginner resonance exercise uses a five-note pentachord foundation: Do, Re, Mi, Fa, Sol.",
              stages=[
                _stage(
                  "forward_hum",
                  title="Forward Hum",
                  solfege="Do",
                  instruction="Begin with a light hum and feel vibration near the lips and nose.",
                  beats=1,
                ),
                _stage(
                  "forward_re",
                  title="Re Lift",
                  solfege="Re",
                  instruction="Move gently upward while keeping the forward buzz.",
                  beats=1,
                ),
                _stage(
                  "open_vowel",
                  title="Open Vowel",
                  solfege="Mi",
                  instruction="Open to a clean vowel without losing the forward buzz.",
                  beats=1,
                ),
                _stage(
                  "forward_fa",
                  title="Fa Lift",
                  solfege="Fa",
                  instruction="Stay relaxed as the tone rises through the vowel.",
                  beats=1,
                ),
                _stage(
                  "bright_hold",
                  title="Bright Hold",
                  solfege="Sol",
                  instruction="Keep the tone bright and lifted while staying relaxed.",
                  beats=2,
                ),
              ],
            ),
            "intermediate": _pattern(
              "placement_arc",
              pattern_type="sustain",
              summary="Sustain and return through a wider resonance arc with smooth resets.",
              stages=[
                _stage(
                  "hum_reset",
                  title="Reset Hum",
                  solfege="Do",
                  instruction="Start with a clean hum and stable support.",
                  beats=1,
                ),
                _stage(
                  "lifted_re",
                  title="Gentle Rise",
                  solfege="Re",
                  instruction="Move up while keeping the same easy support.",
                  beats=1,
                ),
                _stage(
                  "lifted_mi",
                  title="Lifted Placement",
                  solfege="Mi",
                  instruction="Keep the tone forward as the vowel opens.",
                  beats=1,
                ),
                _stage(
                  "lifted_fa",
                  title="Supported Rise",
                  solfege="Fa",
                  instruction="Keep the vowel open without adding throat pressure.",
                  beats=1,
                ),
                _stage(
                  "ringing_sol",
                  title="Ringing Sustain",
                  solfege="Sol",
                  instruction="Maintain ring without tightening the throat.",
                  beats=2,
                ),
                _stage(
                  "release_mi",
                  title="Easy Return",
                  solfege="Mi",
                  instruction="Return smoothly and keep the same placement quality.",
                  beats=1,
                ),
              ],
            ),
            "advanced": _pattern(
              "placement_control_loop",
              pattern_type="sustain",
              summary="Sustained resonance loop with longer holds and placement consistency checks.",
              stages=[
                _stage(
                  "advanced_do",
                  title="Centered Start",
                  solfege="Do",
                  instruction="Start with low breath support and immediate forward placement.",
                  beats=1,
                ),
                _stage(
                  "advanced_re_start",
                  title="Measured Rise",
                  solfege="Re",
                  instruction="Prepare the next pitch while keeping placement forward.",
                  beats=1,
                ),
                _stage(
                  "advanced_mi",
                  title="Lifted Vowel",
                  solfege="Mi",
                  instruction="Keep brightness steady as the pitch rises.",
                  beats=1,
                ),
                _stage(
                  "advanced_fa",
                  title="Supported Rise",
                  solfege="Fa",
                  instruction="Keep support even as the pitch rises.",
                  beats=1,
                ),
                _stage(
                  "advanced_sol",
                  title="Focused Ring",
                  solfege="Sol",
                  instruction="Preserve ring and avoid spreading the vowel.",
                  beats=2,
                ),
                _stage(
                  "advanced_fa_return",
                  title="Controlled Return",
                  solfege="Fa",
                  instruction="Return while keeping support even and relaxed.",
                  beats=1,
                ),
                _stage(
                  "advanced_re_finish",
                  title="Balanced Finish",
                  solfege="Re",
                  instruction="End with the same easy, forward placement.",
                  beats=1,
                ),
              ],
            ),
          },
        },
        {
          "exercise_id": "warmup_pitch",
          "name": "Pitch Warmup",
          "description": "Warm the voice with controlled pitch center and gentle onset.",
          "objective": "Center the voice with clean onsets and stable pitch in a gentle warmup.",
          "what_you_do": "Sing a short note ladder softly, landing each note cleanly before moving to the next one.",
          "requires_microphone": True,
          "exercise_mode": "voice",
          "instructions": [
            "Begin softly and increase gradually.",
            "Hold each target note for 2-3 seconds.",
            "Avoid force; prioritize stability.",
          ],
          "ai_focus": "Pitch center, onset consistency, and warmup control",
          "default_difficulty": "beginner",
          "recommended_order": 2,
          "focus_metrics": ["pitch_accuracy", "timing_accuracy", "pitch_stability"],
          "metric_weights": {
            "pitch_accuracy": 0.35,
            "timing_accuracy": 0.2,
            "breath_control": 0.15,
            "pitch_stability": 0.2,
            "vibrato_consistency": 0.05,
            "note_transition_smoothness": 0.05,
          },
          "success_thresholds": {
            "overall_score": 76,
            "metric_floors": {
              "pitch_accuracy": 74,
              "timing_accuracy": 68,
            },
          },
          "coach_cues": {
            "ready": "Start gently and keep every onset clean.",
            "too_soft": "Support a little more air for a clear start.",
            "on_pitch": "Clean pitch center - stay easy.",
            "low_pitch": "Prepare the note mentally before you sing it.",
            "high_pitch": "Release pressure and enter the note more gently.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "warmup_ladder",
              pattern_type="ladder",
              summary="Complete Do Re Mi Fa Sol warmup ladder for clean, steady onset.",
              stages=[
                _stage(
                  "warmup_do",
                  title="Do Start",
                  solfege="Do",
                  instruction="Start softly and settle on pitch right away.",
                  beats=1,
                ),
                _stage(
                  "warmup_re",
                  title="Re Lift",
                  solfege="Re",
                  instruction="Move up without pushing volume.",
                  beats=2,
                ),
                _stage(
                  "warmup_mi",
                  title="Mi Center",
                  solfege="Mi",
                  instruction="Keep the vowel aligned and centered.",
                  beats=1,
                ),
                _stage(
                  "warmup_fa",
                  title="Fa Lift",
                  solfege="Fa",
                  instruction="Stay relaxed as the ladder rises.",
                  beats=1,
                ),
                _stage(
                  "warmup_sol",
                  title="Sol Peak",
                  solfege="Sol",
                  instruction="Finish the ladder with a clear, steady tone.",
                  beats=1,
                ),
              ],
            ),
            "intermediate": _pattern(
              "warmup_arc",
              pattern_type="ladder",
              summary="Ascend and descend with clean pitch entry and stable tone.",
              stages=[
                _stage(
                  "warmup_arc_do",
                  title="Do Start",
                  solfege="Do",
                  instruction="Begin with a balanced onset.",
                  beats=1,
                ),
                _stage(
                  "warmup_arc_re",
                  title="Re Rise",
                  solfege="Re",
                  instruction="Keep the move light and precise.",
                  beats=1,
                ),
                _stage(
                  "warmup_arc_mi",
                  title="Mi Lock",
                  solfege="Mi",
                  instruction="Hold the center before moving on.",
                  beats=1,
                ),
                _stage(
                  "warmup_arc_fa",
                  title="Fa Lift",
                  solfege="Fa",
                  instruction="Stay easy through the rise.",
                  beats=1,
                ),
                _stage(
                  "warmup_arc_sol",
                  title="Sol Peak",
                  solfege="Sol",
                  instruction="Reach the top note without pressing or lifting the chin.",
                  beats=1,
                ),
                _stage(
                  "warmup_arc_mi_return",
                  title="Mi Return",
                  solfege="Mi",
                  instruction="Return without scooping into the note.",
                  beats=1,
                ),
              ],
            ),
            "advanced": _pattern(
              "warmup_full_ladder",
              pattern_type="ladder",
              summary="Longer ladder that tests clean entry, release, and pitch steadiness.",
              stages=[
                _stage(
                  "warmup_full_do",
                  title="Do Start",
                  solfege="Do",
                  instruction="Start with low effort and clean center.",
                  beats=1,
                ),
                _stage(
                  "warmup_full_re",
                  title="Re Rise",
                  solfege="Re",
                  instruction="Prepare before each move.",
                  beats=1,
                ),
                _stage(
                  "warmup_full_mi",
                  title="Mi Lock",
                  solfege="Mi",
                  instruction="Hold stable before advancing.",
                  beats=1,
                ),
                _stage(
                  "warmup_full_fa",
                  title="Fa Lift",
                  solfege="Fa",
                  instruction="Stay tall and avoid tension.",
                  beats=1,
                ),
                _stage(
                  "warmup_full_sol",
                  title="Sol Peak",
                  solfege="Sol",
                  instruction="Maintain control at the top.",
                  beats=1,
                ),
                _stage(
                  "warmup_full_mi_finish",
                  title="Mi Finish",
                  solfege="Mi",
                  instruction="Return cleanly and stay centered.",
                  beats=1,
                ),
              ],
            ),
          },
        },
        {
          "exercise_id": "note_transition_drill",
          "name": "Note Transition Drill",
          "description": "Improve smooth movement between adjacent target notes.",
          "objective": "Connect notes with controlled transitions and fast pitch settling.",
          "what_you_do": "Sing connected note changes without scooping, dragging, or jumping too hard between pitches.",
          "requires_microphone": True,
          "exercise_mode": "voice",
          "instructions": [
            "Connect notes legato.",
            "Minimize sudden pitch jumps.",
            "Keep the phrase connection even during transitions.",
          ],
          "ai_focus": "Transition smoothness, settling speed, and stability",
          "default_difficulty": "intermediate",
          "recommended_order": 3,
          "focus_metrics": ["note_transition_smoothness", "timing_accuracy", "pitch_stability"],
          "metric_weights": {
            "pitch_accuracy": 0.15,
            "timing_accuracy": 0.2,
            "breath_control": 0.05,
            "pitch_stability": 0.2,
            "vibrato_consistency": 0.05,
            "note_transition_smoothness": 0.35,
          },
          "success_thresholds": {
            "overall_score": 78,
            "metric_floors": {
              "note_transition_smoothness": 74,
              "timing_accuracy": 68,
            },
          },
          "coach_cues": {
            "ready": "Connect each note smoothly without rushing.",
            "too_soft": "Keep the sound connected through the change.",
            "on_pitch": "Smooth landing - keep the line connected.",
            "low_pitch": "Prepare the next note earlier and guide upward.",
            "high_pitch": "Release the jump and settle through the breath.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "transition_steps",
              pattern_type="transition",
              summary="Complete five-note ladder with controlled legato transitions.",
              stages=[
                _stage(
                  "transition_do",
                  title="Do Start",
                  solfege="Do",
                  instruction="Start balanced and ready to move.",
                  beats=1,
                ),
                _stage(
                  "transition_re",
                  title="Re Connect",
                  solfege="Re",
                  instruction="Move smoothly without a hard jump.",
                  beats=1,
                ),
                _stage(
                  "transition_mi",
                  title="Mi Settle",
                  solfege="Mi",
                  instruction="Let the pitch settle quickly and evenly.",
                  beats=1,
                ),
                _stage(
                  "transition_fa",
                  title="Fa Reach",
                  solfege="Fa",
                  instruction="Keep the sound connected as you continue upward.",
                  beats=1,
                ),
                _stage(
                  "transition_sol",
                  title="Sol Finish",
                  solfege="Sol",
                  instruction="Finish the ladder without tightening the throat.",
                  beats=1,
                ),
              ],
            ),
            "intermediate": _pattern(
              "transition_arc",
              pattern_type="transition",
              summary="Complete five-note ladder with a controlled return through the connected line.",
              stages=[
                _stage(
                  "transition_arc_do",
                  title="Do Start",
                  solfege="Do",
                  instruction="Center the line before moving.",
                  beats=1,
                ),
                _stage(
                  "transition_arc_re",
                  title="Re Connect",
                  solfege="Re",
                  instruction="Move smoothly into the next pitch.",
                  beats=1,
                ),
                _stage(
                  "transition_arc_mi",
                  title="Mi Lift",
                  solfege="Mi",
                  instruction="Travel smoothly into the next pitch.",
                  beats=1,
                ),
                _stage(
                  "transition_arc_fa",
                  title="Fa Reach",
                  solfege="Fa",
                  instruction="Keep the sound connected through the reach.",
                  beats=1,
                ),
                _stage(
                  "transition_arc_sol",
                  title="Sol Peak",
                  solfege="Sol",
                  instruction="Reach the top without breaking the connected line.",
                  beats=1,
                ),
                _stage(
                  "transition_arc_mi_finish",
                  title="Mi Finish",
                  solfege="Mi",
                  instruction="Land and stabilize quickly.",
                  beats=1,
                ),
              ],
            ),
            "advanced": _pattern(
              "transition_skips",
              pattern_type="transition",
              summary="Complete five-note ladder followed by controlled return transitions.",
              teaching_note="This advanced transition exercise first follows Do, Re, Mi, Fa, Sol, then returns through selected notes to build connected control.",
              stages=[
                _stage(
                  "transition_skip_do",
                  title="Do Start",
                  solfege="Do",
                  instruction="Stay poised and ready to connect the line.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_re",
                  title="Re Connect",
                  solfege="Re",
                  instruction="Move smoothly without breaking the line.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_mi",
                  title="Mi Lift",
                  solfege="Mi",
                  instruction="Travel upward with a steady vowel.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_fa",
                  title="Fa Reach",
                  solfege="Fa",
                  instruction="Keep the sound connected through the reach.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_sol",
                  title="Sol Extend",
                  solfege="Sol",
                  instruction="Keep the line connected through the top note.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_fa_return",
                  title="Fa Return",
                  solfege="Fa",
                  instruction="Return smoothly without collapsing support.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_re_return",
                  title="Re Balance",
                  solfege="Re",
                  instruction="Settle quickly into the lower pitch.",
                  beats=1,
                ),
                _stage(
                  "transition_skip_mi_finish",
                  title="Mi Finish",
                  solfege="Mi",
                  instruction="Finish with the same connected tone.",
                  beats=1,
                ),
              ],
            ),
          },
        },
      ],
    },
    {
      "category_id": "do_re_mi",
      "title": "Do Re Mi Fa Sol",
      "subtitle": "Pitch-target drills and interval control",
      "description": "Strengthen ear-voice mapping and note accuracy.",
      "exercises": [
        {
          "exercise_id": "do_re_mi_basic_ladder",
          "name": "Basic Ladder",
          "description": "Step through scale tones with clean pitch locks.",
          "objective": "Build scale awareness and clean pitch locks on simple note ladders.",
          "what_you_do": "Sing one target note at a time in order, matching each step before climbing to the next one.",
          "requires_microphone": True,
          "exercise_mode": "voice",
          "instructions": [
            "Follow target notes in sequence.",
            "Hold each note until it stabilizes.",
            "Reset breath between phrases.",
          ],
          "ai_focus": "Cents error reduction and note-hit consistency",
          "default_difficulty": "beginner",
          "recommended_order": 1,
          "focus_metrics": ["pitch_accuracy", "timing_accuracy", "pitch_stability"],
          "metric_weights": {
            "pitch_accuracy": 0.35,
            "timing_accuracy": 0.2,
            "breath_control": 0.1,
            "pitch_stability": 0.2,
            "vibrato_consistency": 0.05,
            "note_transition_smoothness": 0.1,
          },
          "success_thresholds": {
            "overall_score": 75,
            "metric_floors": {
              "pitch_accuracy": 72,
            },
          },
          "coach_cues": {
            "ready": "Track each note before you sing it.",
            "too_soft": "Use a clear, comfortable sound so the pitch can be detected reliably.",
            "on_pitch": "Nice lock - hold it steady.",
            "low_pitch": "Aim a touch higher into the note.",
            "high_pitch": "Relax the attack and settle into center.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "basic_ladder",
              pattern_type="ladder",
              summary="Straight scale ladder to reinforce note recognition.",
              teaching_note="This is the beginner pentachord foundation: Do, Re, Mi, Fa, Sol. Higher levels add La, Ti, and high Do.",
              stages=[
                _stage("ladder_do", title="Do", solfege="Do", instruction="Lock the tonic cleanly.", beats=1),
                _stage("ladder_re", title="Re", solfege="Re", instruction="Move up without sliding.", beats=1),
                _stage("ladder_mi", title="Mi", solfege="Mi", instruction="Keep the center steady.", beats=1),
                _stage("ladder_fa", title="Fa", solfege="Fa", instruction="Stay relaxed as you rise.", beats=1),
                _stage("ladder_sol", title="Sol", solfege="Sol", instruction="Lock the top note clearly.", beats=1),
              ],
            ),
            "intermediate": _pattern(
              "basic_ladder_extended",
              pattern_type="ladder",
              summary="Complete scale ladder with a controlled return pattern.",
              stages=[
                _stage("ladder_ext_do", title="Do", solfege="Do", instruction="Start cleanly.", beats=1),
                _stage("ladder_ext_re", title="Re", solfege="Re", instruction="Prepare before moving.", beats=1),
                _stage("ladder_ext_mi", title="Mi", solfege="Mi", instruction="Hold the center.", beats=1),
                _stage("ladder_ext_fa", title="Fa", solfege="Fa", instruction="Stay relaxed as you rise.", beats=1),
                _stage("ladder_ext_sol", title="Sol", solfege="Sol", instruction="Lock the top note clearly.", beats=1),
                _stage("ladder_ext_mi_return", title="Mi", solfege="Mi", instruction="Return without scooping.", beats=1),
              ],
            ),
            "advanced": _pattern(
              "basic_ladder_full",
              pattern_type="ladder",
              summary="Full ladder through a wider pitch span.",
              stages=[
                _stage("ladder_full_do", title="Do", solfege="Do", instruction="Start centered.", beats=1),
                _stage("ladder_full_re", title="Re", solfege="Re", instruction="Keep the move direct.", beats=1),
                _stage("ladder_full_mi", title="Mi", solfege="Mi", instruction="Hold stable.", beats=1),
                _stage("ladder_full_fa", title="Fa", solfege="Fa", instruction="Stay tall in the rise.", beats=1),
                _stage("ladder_full_sol", title="Sol", solfege="Sol", instruction="Lock the top note clearly.", beats=1),
                _stage("ladder_full_fa_return", title="Fa", solfege="Fa", instruction="Descend with control.", beats=1),
              ],
            ),
          },
        },
        {
          "exercise_id": "do_re_mi_interval_jumps",
          "name": "Interval Jumps",
          "description": "Land non-adjacent notes with precision.",
          "objective": "Improve interval anticipation and direct note landing.",
          "what_you_do": "Hear the next note in your mind, then jump directly to it without sliding into the pitch.",
          "requires_microphone": True,
          "exercise_mode": "voice",
          "instructions": [
            "Visualize the target note before singing.",
            "Attack cleanly; avoid sliding.",
            "Check stability after each jump.",
          ],
          "ai_focus": "Interval landing precision and recovery speed",
          "default_difficulty": "advanced",
          "recommended_order": 2,
          "focus_metrics": ["pitch_accuracy", "note_transition_smoothness", "timing_accuracy"],
          "metric_weights": {
            "pitch_accuracy": 0.35,
            "timing_accuracy": 0.2,
            "breath_control": 0.05,
            "pitch_stability": 0.15,
            "vibrato_consistency": 0.05,
            "note_transition_smoothness": 0.2,
          },
          "success_thresholds": {
            "overall_score": 78,
            "metric_floors": {
              "pitch_accuracy": 75,
            },
          },
          "coach_cues": {
            "ready": "Hear the interval before you sing it.",
            "too_soft": "Support enough air to land the jump cleanly.",
            "on_pitch": "Direct landing - keep it stable.",
            "low_pitch": "Prepare the leap higher in your mind.",
            "high_pitch": "Release the jump and land with less force.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "interval_jumps_short",
              pattern_type="jump",
              summary="Simple interval jumps for controlled landing.",
              stages=[
                _stage("jump_short_do", title="Do", solfege="Do", instruction="Set the tonic clearly.", beats=1),
                _stage("jump_short_mi", title="Mi", solfege="Mi", instruction="Jump directly into the note.", beats=1),
                _stage("jump_short_do_return", title="Do", solfege="Do", instruction="Return without sliding.", beats=1),
              ],
            ),
            "intermediate": _pattern(
              "interval_jumps_medium",
              pattern_type="jump",
              summary="Alternating interval jumps with fast recovery.",
              stages=[
                _stage("jump_medium_do", title="Do", solfege="Do", instruction="Start centered.", beats=1),
                _stage("jump_medium_fa", title="Fa", solfege="Fa", instruction="Leap directly and stabilize.", beats=1),
                _stage("jump_medium_re", title="Re", solfege="Re", instruction="Return cleanly.", beats=1),
                _stage("jump_medium_sol", title="Sol", solfege="Sol", instruction="Keep the landing direct.", beats=1),
                _stage("jump_medium_mi", title="Mi", solfege="Mi", instruction="Recover into the next center.", beats=1),
              ],
            ),
            "advanced": _pattern(
              "interval_jumps_full",
              pattern_type="jump",
              summary="Full-octave interval jumps that test anticipation and pitch control.",
              stages=[
                _stage("jump_full_do", title="Do", solfege="Do", instruction="Set a stable tonic.", beats=1),
                _stage("jump_full_sol", title="Sol", solfege="Sol", instruction="Land directly on the top note.", beats=1),
                _stage("jump_full_mi", title="Mi", solfege="Mi", instruction="Recover with the same clarity.", beats=1),
                _stage("jump_full_la", title="La", solfege="La", instruction="Prepare the wider leap before you sing.", beats=1),
                _stage("jump_full_ti", title="Ti", solfege="Ti", instruction="Prepare mentally before the leap.", beats=1),
                _stage("jump_full_fa", title="Fa", solfege="Fa", instruction="Return without dropping support.", beats=1),
                _stage("jump_full_high_do", title="High Do", solfege="Do′", instruction="Reach the octave gently and keep the landing stable.", beats=1),
                _stage("jump_full_sol_return", title="Sol", solfege="Sol", instruction="Recover from the octave without sliding.", beats=1),
                _stage("jump_full_do_finish", title="Do", solfege="Do", instruction="Finish centered and stable.", beats=1),
              ],
            ),
          },
        },
      ],
    },
    {
      "category_id": "breathing",
      "title": "Breathing",
      "subtitle": "Breath pacing, body awareness, and phrase endurance",
      "description": "Develop breath management for sustained and stable singing.",
      "exercises": [
        {
          "exercise_id": "breath_support_ladder",
          "name": "Support Ladder",
          "description": "Follow guided inhale and exhale counts to practice repeatable breath pacing.",
          "objective": "Practice repeatable breath timing through gradually longer inhale and exhale cycles.",
          "what_you_do": "Follow the timer to inhale, hold briefly if prompted, and exhale slowly through each guided cycle.",
          "requires_microphone": False,
          "exercise_mode": "breathing_timer",
          "instructions": [
            "Inhale low and quiet.",
            "Exhale at steady pressure for the full count.",
            "Keep shoulders relaxed while the timer guides you.",
          ],
          "ai_focus": "Breath pacing, routine consistency, and phase completion quality",
          "default_difficulty": "beginner",
          "recommended_order": 1,
          "focus_metrics": [
            "phase_completion_rate",
            "pace_adherence",
            "cycle_consistency",
          ],
          "metric_weights": {
            "phase_completion_rate": 0.35,
            "pace_adherence": 0.3,
            "cycle_consistency": 0.2,
            "completion_rate": 0.15,
          },
          "success_thresholds": {
            "overall_score": 74,
            "metric_floors": {
              "phase_completion_rate": 72,
              "pace_adherence": 68,
            },
          },
          "coach_cues": {
            "ready": "Set the ribs low and get ready to follow the next breath phase.",
            "too_soft": "Keep the exhale even all the way through the release.",
            "on_pitch": "Nice pacing - keep the inhale quiet and the exhale even.",
            "low_pitch": "Take a fuller, calmer inhale before the next release.",
            "high_pitch": "Slow the air down and soften the pressure on the exhale.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "support_ladder_short",
              pattern_type="breathing",
              summary="Short guided breathing ladder with simple inhale and longer exhale pacing.",
              stages=[
                _stage("support_inhale_short", title="Inhale", solfege="Inhale", instruction="Breathe in quietly through the nose for the full count.", beats=1),
                _stage("support_hold_short", title="Settle", solfege="Settle", instruction="Pause briefly and stay relaxed through the ribs.", beats=1),
                _stage("support_exhale_short", title="Exhale", solfege="Exhale", instruction="Release the air slowly and evenly until the timer ends.", beats=2),
              ],
            ),
            "intermediate": _pattern(
              "support_ladder_medium",
              pattern_type="breathing",
              summary="Medium breathing ladder with longer exhale pacing and posture control.",
              stages=[
                _stage("support_medium_inhale", title="Inhale", solfege="Inhale", instruction="Fill low and wide without lifting the shoulders.", beats=1),
                _stage("support_medium_hold", title="Anchor", solfege="Anchor", instruction="Keep the ribs open and avoid throat tension.", beats=1),
                _stage("support_medium_exhale", title="Exhale", solfege="Exhale", instruction="Let the air out in a slow, controlled stream.", beats=2),
                _stage("support_medium_release", title="Recover", solfege="Recover", instruction="Stay tall and reset calmly before the next cycle.", beats=2),
              ],
            ),
            "advanced": _pattern(
              "support_ladder_full",
              pattern_type="breathing",
              summary="Long guided breathing cycle for advanced support pacing and controlled release.",
              stages=[
                _stage("support_full_inhale", title="Inhale", solfege="Inhale", instruction="Take a low, silent inhale without rushing.", beats=1),
                _stage("support_full_hold", title="Hold", solfege="Hold", instruction="Keep the body expanded and steady.", beats=1),
                _stage("support_full_exhale", title="Exhale", solfege="Exhale", instruction="Release the air with the same support all the way through.", beats=2),
                _stage("support_full_extend", title="Extend", solfege="Extend", instruction="Stay calm as the exhale gets longer.", beats=2),
                _stage("support_full_reset", title="Reset", solfege="Reset", instruction="Relax, recover, and prepare for the next cycle.", beats=2),
              ],
            ),
          },
        },
        {
          "exercise_id": "long_phrase_breathing",
          "name": "Long Phrase Breathing",
          "description": "Practice longer inhale-to-exhale cycles that mimic the pacing needed for long singing phrases.",
          "objective": "Improve phrase planning and exhale pacing through guided long-breath timing.",
          "what_you_do": "Use the timer to inhale, then stretch a calm, even exhale for longer phrase-style counts.",
          "requires_microphone": False,
          "exercise_mode": "breathing_timer",
          "instructions": [
            "Inhale quietly before each cycle.",
            "Pace the exhale instead of pushing air out early.",
            "Stay relaxed until the end of the count.",
          ],
          "ai_focus": "Exhale pacing, endurance, and guided phrase completion",
          "default_difficulty": "intermediate",
          "recommended_order": 2,
          "focus_metrics": [
            "phase_completion_rate",
            "pace_adherence",
            "completion_rate",
          ],
          "metric_weights": {
            "phase_completion_rate": 0.3,
            "pace_adherence": 0.3,
            "cycle_consistency": 0.15,
            "completion_rate": 0.25,
          },
          "success_thresholds": {
            "overall_score": 76,
            "metric_floors": {
              "phase_completion_rate": 74,
              "completion_rate": 72,
            },
          },
          "coach_cues": {
            "ready": "Plan the breath now and stay calm through the longer release.",
            "too_soft": "Keep the support connected as the phrase keeps going.",
            "on_pitch": "That pacing is steady - keep the exhale smooth to the end.",
            "low_pitch": "Reset calmly so the next long release stays comfortable.",
            "high_pitch": "Back off the pressure and spread the air across the full phrase.",
          },
          "patterns_by_difficulty": {
            "beginner": _pattern(
              "long_phrase_short",
              pattern_type="breathing",
              summary="Short phrase-style breathing cycle with a measured inhale and longer exhale.",
              stages=[
                _stage("phrase_short_inhale", title="Inhale", solfege="Inhale", instruction="Take a quiet inhale and keep the chest relaxed.", beats=1),
                _stage("phrase_short_exhale", title="Exhale", solfege="Exhale", instruction="Let the air out evenly through the whole count.", beats=1),
                _stage("phrase_short_finish", title="Finish", solfege="Finish", instruction="Stay steady through the final seconds of the exhale.", beats=2),
              ],
            ),
            "intermediate": _pattern(
              "long_phrase_medium",
              pattern_type="breathing",
              summary="Longer phrase-style breathing drill with endurance emphasis.",
              stages=[
                _stage("phrase_medium_inhale", title="Inhale", solfege="Inhale", instruction="Set the breath low and calm before the long exhale.", beats=1),
                _stage("phrase_medium_release", title="Release", solfege="Release", instruction="Begin the exhale smoothly without dumping air.", beats=1),
                _stage("phrase_medium_extend", title="Extend", solfege="Extend", instruction="Keep the exhale even as the count gets longer.", beats=2),
                _stage("phrase_medium_finish", title="Finish", solfege="Finish", instruction="Stay supported right to the end.", beats=2),
              ],
            ),
            "advanced": _pattern(
              "long_phrase_full",
              pattern_type="breathing",
              summary="Advanced long-breath routine with multiple pacing checkpoints and a controlled finish.",
              stages=[
                _stage("phrase_full_inhale", title="Inhale", solfege="Inhale", instruction="Prepare the body with a slow, quiet inhale.", beats=1),
                _stage("phrase_full_anchor", title="Anchor", solfege="Anchor", instruction="Hold the expansion briefly without tightening.", beats=1),
                _stage("phrase_full_release", title="Release", solfege="Release", instruction="Start the exhale in a controlled, even stream.", beats=2),
                _stage("phrase_full_extend", title="Extend", solfege="Extend", instruction="Resist the urge to push as the count lengthens.", beats=2),
                _stage("phrase_full_finish", title="Finish", solfege="Finish", instruction="Stay calm and supported through the final seconds.", beats=2),
                _stage("phrase_full_reset", title="Reset", solfege="Reset", instruction="Release tension and prepare for the next cycle.", beats=2),
              ],
            ),
          },
        },
      ],
    },
  ],
}


def _full_scale_stage(label: str, index: int, pattern_id: str) -> dict[str, Any]:
  stage_id = f"{pattern_id}_full_{index + 1}"
  title = "High Do" if label == "Do′" else label
  instruction = (
    "Reach the octave gently and keep the landing stable."
    if label == "Do′"
    else f"Prepare the {label} before moving to the next scale degree."
  )
  return _stage(
    stage_id,
    title=title,
    solfege=label,
    instruction=instruction,
    beats=1,
  )


def _decorate_pattern(
  exercise_id: str,
  difficulty: str,
  pattern: dict[str, Any],
) -> dict[str, Any]:
  decorated = deepcopy(pattern)
  pattern_type = str(decorated.get("pattern_type") or "")
  stages = list(decorated.get("stages") or [])
  labels = [str(stage.get("target_label") or stage.get("solfege") or "") for stage in stages]

  if difficulty != "beginner" and pattern_type in {"ladder", "sustain", "transition"}:
    prefix_length = 5 if labels[:5] == list(_FULL_SCALE[:5]) else 0
    if prefix_length:
      missing_scale_stages = [
        _full_scale_stage(label, index, str(decorated.get("pattern_id") or exercise_id))
        for index, label in enumerate(_FULL_SCALE[prefix_length:], start=prefix_length)
        if label not in labels
      ]
      decorated["stages"] = stages[:prefix_length] + missing_scale_stages + stages[prefix_length:]
      stages = list(decorated["stages"])
      labels = [str(stage.get("target_label") or stage.get("solfege") or "") for stage in stages]

  if pattern_type in {"ladder", "sustain", "transition"}:
    if difficulty == "beginner":
      decorated["teaching_note"] = (
        "This beginner pattern uses the five-note pentachord foundation: "
        "Do, Re, Mi, Fa, Sol. Higher levels add La, Ti, and high Do."
      )
    else:
      decorated["teaching_note"] = (
        "This pattern starts with the five-note pentachord foundation and expands "
        "through the full octave: Do, Re, Mi, Fa, Sol, La, Ti, high Do."
      )
  elif pattern_type == "jump" and difficulty == "advanced":
    decorated["teaching_note"] = (
      "This interval exercise intentionally skips scale steps; the advanced range "
      "includes La, Ti, and high Do so the full octave is tested."
    )

  return decorated


def _decorated_catalog() -> dict[str, Any]:
  catalog = deepcopy(_VOCAL_COACH_CATALOG)
  for category in catalog["categories"]:
    if category["category_id"] == "do_re_mi":
      category["title"] = "Do Re Mi Fa Sol La Ti Do"
    for exercise in category["exercises"]:
      metadata = _TRAINING_EVIDENCE_METADATA.get(exercise["exercise_id"], {})
      exercise.update(
        {
          "training_basis": list(metadata.get("training_basis") or []),
          "measurement_plan": list(metadata.get("measurement_plan") or []),
          "measurement_limits": list(metadata.get("measurement_limits") or []),
        }
      )
      exercise["patterns_by_difficulty"] = {
        difficulty: _decorate_pattern(exercise["exercise_id"], difficulty, pattern)
        for difficulty, pattern in exercise["patterns_by_difficulty"].items()
      }
  return catalog


def get_catalog() -> dict[str, Any]:
  return _decorated_catalog()


def list_categories() -> list[dict[str, Any]]:
  return get_catalog()["categories"]


def get_category(category_id: str) -> dict[str, Any] | None:
  normalized = category_id.strip().lower()
  for category in get_catalog()["categories"]:
    if category["category_id"] == normalized:
      return deepcopy(category)
  return None


def list_exercises(category_id: str | None = None) -> list[dict[str, Any]]:
  categories = get_catalog()["categories"]
  if category_id:
    normalized = category_id.strip().lower()
    categories = [item for item in categories if item["category_id"] == normalized]

  items: list[dict[str, Any]] = []
  for category in categories:
    for exercise in category["exercises"]:
      items.append(
        {
          **exercise,
          "category_id": category["category_id"],
          "category_title": category["title"],
        }
      )
  return deepcopy(items)


def get_exercise(exercise_id: str) -> dict[str, Any] | None:
  normalized = exercise_id.strip().lower()
  for exercise in list_exercises():
    if exercise["exercise_id"] == normalized:
      return deepcopy(exercise)
  return None


def resolve_duration_sec(difficulty: DifficultyLevel) -> int:
  levels = _DEFAULT_ATTEMPT_POLICY["duration_sec_by_difficulty"]
  return int(levels.get(difficulty, levels["beginner"]))


def default_attempt_policy() -> dict[str, Any]:
  return deepcopy(_DEFAULT_ATTEMPT_POLICY)


def default_metric_weights() -> dict[str, float]:
  return deepcopy(_DEFAULT_METRIC_WEIGHTS)
