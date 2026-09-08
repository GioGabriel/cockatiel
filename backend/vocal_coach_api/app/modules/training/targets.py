"""Canonical pitch targets shared by training runtime and feedback evidence.

The backend owns the movable-do mapping so the target shown to a singer, the
reference frequency sent to the client, and the value used by the scorer have
one auditable source. Frequencies use equal temperament with A4 = 440 Hz. The
result is a practice reference, not a claim about the singer's ideal range.
"""

import math
from typing import Any

_KEY_SEMITONES = {
  "C": 0,
  "C#": 1,
  "D": 2,
  "D#": 3,
  "E": 4,
  "F": 5,
  "F#": 6,
  "G": 7,
  "G#": 8,
  "A": 9,
  "A#": 10,
  "B": 11,
}

_SOLFEGE_TARGETS = {
  "do": (1, 0, False),
  "re": (2, 2, False),
  "mi": (3, 4, False),
  "fa": (4, 5, False),
  "sol": (5, 7, False),
  "so": (5, 7, False),
  "la": (6, 9, False),
  "ti": (7, 11, False),
  "si": (7, 11, False),
  "high do": (8, 12, True),
}


def _normalize_key(key: str) -> str:
  normalized = str(key or "C").strip().upper()
  return normalized if normalized in _KEY_SEMITONES else "C"


def _normalize_octave(octave: int) -> int:
  return max(2, min(int(octave or 4), 6))


def _solfege_target(solfege: str) -> tuple[int, int, bool] | None:
  normalized = str(solfege or "").strip().lower()
  normalized = normalized.replace("′", "'").replace("’", "'")
  is_high = normalized.endswith("'")
  normalized = normalized.rstrip("'").strip()
  if normalized in _SOLFEGE_TARGETS:
    degree, offset, configured_high = _SOLFEGE_TARGETS[normalized]
    resolved_degree = 8 if is_high and normalized == "do" else degree
    return resolved_degree, offset + (12 if is_high and not configured_high else 0), is_high or configured_high
  if normalized.startswith("high "):
    base = normalized[5:].strip()
    target = _SOLFEGE_TARGETS.get(base)
    if target:
      degree, offset, _ = target
      return degree + 1 if degree == 1 else degree, offset + 12, True
  return None


def canonical_training_target(
  *,
  target_id: str,
  solfege: str,
  key: str,
  octave: int,
  start_sec: float,
  end_sec: float,
  rest_after_sec: float,
  target_type: str | None = None,
  breath_cue: bool | None = None,
) -> dict[str, Any]:
  """Return the canonical target contract for a runtime stage.

  Breathing phases intentionally retain a target object with null pitch
  fields. That keeps the contract uniform while making it impossible for a
  breathing label such as ``Inhale`` to become an accidental pitch target.
  """

  normalized_key = _normalize_key(key)
  normalized_octave = _normalize_octave(octave)
  target = _solfege_target(solfege)
  note_duration = round(max(float(end_sec) - float(start_sec), 0.0), 2)
  rest = round(max(float(rest_after_sec), 0.0), 2)

  if target is None:
    resolved_type = target_type or "breathing_phase"
    return {
      "target_id": str(target_id),
      "solfege": str(solfege),
      "scale_degree": None,
      "midi_note": None,
      "target_frequency_hz": None,
      "key": normalized_key,
      "octave": normalized_octave,
      "start_sec": round(float(start_sec), 2),
      "end_sec": round(float(end_sec), 2),
      "intended_note_duration_sec": note_duration,
      "rest_after_sec": rest,
      "target_type": resolved_type,
      "breath_cue": True if breath_cue is None else bool(breath_cue),
    }

  scale_degree, semitone_offset, _ = target
  midi_note = ((normalized_octave + 1) * 12) + _KEY_SEMITONES[normalized_key] + semitone_offset
  frequency_hz = round(440.0 * math.pow(2.0, (midi_note - 69) / 12.0), 2)
  resolved_type = target_type or "sustained_note"
  return {
    "target_id": str(target_id),
    "solfege": str(solfege),
    "scale_degree": scale_degree,
    "midi_note": midi_note,
    "target_frequency_hz": frequency_hz,
    "key": normalized_key,
    "octave": normalized_octave,
    "start_sec": round(float(start_sec), 2),
    "end_sec": round(float(end_sec), 2),
    "intended_note_duration_sec": note_duration,
    "rest_after_sec": rest,
    "target_type": resolved_type,
    "breath_cue": bool(breath_cue) if breath_cue is not None else rest >= 0.5,
  }
