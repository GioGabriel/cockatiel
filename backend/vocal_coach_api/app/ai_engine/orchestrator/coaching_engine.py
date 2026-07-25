from typing import Any

class CoachingLogicEngine:
  @staticmethod
  def evaluate(overall_score: float, exercise_type: str, metric_summary: dict[str, float | int]) -> tuple[list[str], list[str], list[str]]:
    strengths: list[str] = []
    improvements: list[str] = []
    next_exercises: list[str] = []

    # Identify metric mode (voice vs breathing)
    is_breathing = metric_summary.get("metric_mode") == "breathing"

    if is_breathing:
      CoachingLogicEngine._evaluate_breathing(metric_summary, strengths, improvements, next_exercises)
    else:
      CoachingLogicEngine._evaluate_voice(metric_summary, strengths, improvements, next_exercises)

    # General Fallbacks
    if not strengths:
      if overall_score >= 85:
        strengths.append("Exceptional overall performance consistency")
      elif overall_score >= 70:
        strengths.append("Solid effort with good foundational technique")
      else:
        strengths.append("Great dedication to practicing and completing the exercise")

    if not improvements:
      if overall_score < 95:
        improvements.append("Continue refining micro-dynamics and emotional expression")
      else:
        improvements.append("Ready for advanced stylistic challenges")

    if not next_exercises:
      if "karaoke" in exercise_type.lower():
        next_exercises.append("Advanced phrasing and emotional delivery")
      elif is_breathing:
        next_exercises.append("Extended breath hold ladder")
      else:
        next_exercises.append("Advanced vocal agility and melisma drill")

    # Limit to top 3 most important points to avoid overwhelming the user
    return strengths[:3], improvements[:3], next_exercises[:3]

  @staticmethod
  def _evaluate_voice(metrics: dict[str, Any], strengths: list[str], improvements: list[str], next_exercises: list[str]) -> None:
    pitch_accuracy = metrics.get("pitch_accuracy", 0.0)
    pitch_stability = metrics.get("pitch_stability", 0.0)
    timing_accuracy = metrics.get("timing_accuracy", 0.0)
    breath_control = metrics.get("breath_control", 0.0)
    vibrato_consistency = metrics.get("vibrato_consistency", 0.0)
    transition_smoothness = metrics.get("note_transition_smoothness", 0.0)

    # Pitch Logic
    if pitch_accuracy >= 90:
      strengths.append("Flawless pitch accuracy and pinpoint intonation")
    elif pitch_accuracy >= 80:
      strengths.append("Good general pitch accuracy, mostly centered")
    elif pitch_accuracy < 70:
      improvements.append("Pitch center drifts frequently; notes are often flat or sharp")
      next_exercises.append("Slow interval matching drill with drone accompaniment")
    
    if pitch_stability >= 85:
      strengths.append("Excellent pitch stability on sustained notes")
    elif pitch_stability < 75:
      improvements.append("Wavering pitch on long held notes")
      next_exercises.append("Straight-tone sustain exercises")

    # Timing / Rhythm Logic
    if timing_accuracy >= 90:
      strengths.append("Impeccable rhythmic alignment and deep pocket groove")
    elif timing_accuracy >= 80:
      strengths.append("Solid timing and rhythm lock")
    elif timing_accuracy < 70:
      improvements.append("Rushing or dragging phrases out of time")
      next_exercises.append("Subdivision and metronome sync drills")

    # Breath Control Logic
    if breath_control >= 85:
      strengths.append("Strong diaphragmatic breath support through phrases")
    elif breath_control < 70:
      improvements.append("Running out of air before the end of phrases")
      next_exercises.append("Fricative (hissing) breath pacing ladder")

    # Vibrato Logic
    if vibrato_consistency >= 85:
      strengths.append("Beautiful, even, and controlled vibrato rate")
    elif vibrato_consistency > 0 and vibrato_consistency < 60: # Assuming 0 might mean no vibrato attempted
      improvements.append("Vibrato is uneven or forced (tremolo/wobble)")
      next_exercises.append("Vibrato oscillation speed control drill")

    # Transition Smoothness (Legato)
    if transition_smoothness >= 85:
      strengths.append("Seamless and fluid legato note transitions")
    elif transition_smoothness < 70:
      improvements.append("Clunky or scooped transitions between intervals")
      next_exercises.append("Glissando and portamento smoothing exercises")

  @staticmethod
  def _evaluate_breathing(metrics: dict[str, Any], strengths: list[str], improvements: list[str], next_exercises: list[str]) -> None:
    phase_completion = metrics.get("phase_completion_rate", 0.0)
    pace_adherence = metrics.get("pace_adherence", 0.0)
    cycle_consistency = metrics.get("cycle_consistency", 0.0)
    interruption_count = metrics.get("interruption_count", 0)

    if phase_completion >= 90:
      strengths.append("Fully completed inhale, suspend, and exhale phases")
    elif phase_completion < 75:
      improvements.append("Prematurely releasing or failing to complete breath phases")
      next_exercises.append("Beginner 4-4-4 box breathing")

    if pace_adherence >= 90:
      strengths.append("Perfect adherence to the rhythmic breathing pace")
    elif pace_adherence < 75:
      improvements.append("Inhaling or exhaling too quickly for the designated pace")
      next_exercises.append("Slow-paced metronome breathing")

    if cycle_consistency >= 85:
      strengths.append("Highly consistent breath volume across multiple cycles")
    elif cycle_consistency < 70:
      improvements.append("Inconsistent breath volumes (shallow breaths mixed with deep)")

    if interruption_count == 0:
      strengths.append("Uninterrupted, focused breathing cycles")
    elif interruption_count > 2:
      improvements.append("Multiple flow interruptions detected during the exercise")
      next_exercises.append("Focus and relaxation meditation")
