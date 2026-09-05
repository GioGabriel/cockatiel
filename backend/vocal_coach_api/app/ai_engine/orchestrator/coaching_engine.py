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
        strengths.append("Very consistent overall performance")
      elif overall_score >= 70:
        strengths.append("A solid effort with good foundations")
      else:
        strengths.append("Great dedication to practicing and completing the exercise")

    if not improvements:
      if overall_score < 95:
        improvements.append("Keep refining small changes in volume and expression")
      else:
        improvements.append("Ready for advanced stylistic challenges")

    if not next_exercises:
      if "karaoke" in exercise_type.lower():
        next_exercises.append("Advanced phrasing and emotional delivery")
      elif is_breathing:
        next_exercises.append("Extended breath hold ladder")
      else:
        next_exercises.append("Vocal agility and note-connection drill")

    # Limit to top 3 most important points to avoid overwhelming the user
    return strengths[:3], improvements[:3], next_exercises[:3]

  @staticmethod
  def generate_fallback_summary(
    overall_score: float,
    exercise_type: str,
    metric_summary: dict[str, Any],
    strengths: list[str],
    improvements: list[str],
  ) -> str:
    score_int = int(round(overall_score))
    mode_label = "Karaoke song performance" if "karaoke" in exercise_type.lower() else "Vocal Coach training session"
    
    parts = [f"You achieved an overall score of {score_int}% on this {mode_label}."]
    if strengths:
      parts.append(f"Your primary strength was your {strengths[0].lower()}.")
    if improvements:
      parts.append(f"To reach the next level, focus on improving where {improvements[0].lower()}.")
    else:
      parts.append("Your acoustic metrics were outstanding across the board with no major technical flaws detected.")
      
    parts.append("Short, regular practice will help these skills feel more natural.")
    return " ".join(parts)

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
      strengths.append("Pitch stayed very close to each target")
    elif pitch_accuracy >= 80:
      strengths.append("Most notes were centered close to the target")
    elif pitch_accuracy < 70:
      improvements.append("Several notes drifted above or below the target")
      next_exercises.append("Slow note-matching drill with a steady reference tone")
    
    if pitch_stability >= 85:
      strengths.append("Held notes stayed steady")
    elif pitch_stability < 75:
      improvements.append("Held notes wavered a little")
      next_exercises.append("Short, steady-note holds")

    # Timing / Rhythm Logic
    if timing_accuracy >= 90:
      strengths.append("Your notes lined up very closely with the beat")
    elif timing_accuracy >= 80:
      strengths.append("Good timing and rhythm")
    elif timing_accuracy < 70:
      improvements.append("Some phrases rushed or fell behind the beat")
      next_exercises.append("Beat-counting and metronome practice")

    # Breath Control Logic
    if breath_control >= 85:
      strengths.append("Breath support stayed steady through the phrases")
    elif breath_control < 70:
      improvements.append("You ran out of air before some phrases ended")
      next_exercises.append("Gentle 'sss' breath-pacing ladder")

    # Vibrato Logic
    if vibrato_consistency >= 85:
      strengths.append("Vibrato sounded even and controlled")
    elif vibrato_consistency > 0 and vibrato_consistency < 60: # Assuming 0 might mean no vibrato attempted
      improvements.append("Vibrato was uneven or felt forced")
      next_exercises.append("Gentle vibrato-control drill")

    # Transition Smoothness (Legato)
    if transition_smoothness >= 85:
      strengths.append("Transitions between notes were smooth")
    elif transition_smoothness < 70:
      improvements.append("Some note changes sounded abrupt or slid into place")
      next_exercises.append("Connected note-transition practice")

  @staticmethod
  def _evaluate_breathing(metrics: dict[str, Any], strengths: list[str], improvements: list[str], next_exercises: list[str]) -> None:
    phase_completion = metrics.get("phase_completion_rate", 0.0)
    pace_adherence = metrics.get("pace_adherence", 0.0)
    cycle_consistency = metrics.get("cycle_consistency", 0.0)
    interruption_count = metrics.get("interruption_count", 0)

    if phase_completion >= 90:
      strengths.append("You completed each inhale, hold, and exhale phase")
    elif phase_completion < 75:
      improvements.append("Some breathing phases ended too early")
      next_exercises.append("Beginner 4-4-4 breathing")

    if pace_adherence >= 90:
      strengths.append("Your breathing pace matched the exercise")
    elif pace_adherence < 75:
      improvements.append("Some inhales or exhales were too fast")
      next_exercises.append("Slow metronome breathing")

    if cycle_consistency >= 85:
      strengths.append("Breath volume stayed consistent across cycles")
    elif cycle_consistency < 70:
      improvements.append("Breaths varied between shallow and deep")

    if interruption_count == 0:
      strengths.append("Uninterrupted, focused breathing cycles")
    elif interruption_count > 2:
      improvements.append("Multiple flow interruptions detected during the exercise")
      next_exercises.append("Focus and relaxation meditation")
