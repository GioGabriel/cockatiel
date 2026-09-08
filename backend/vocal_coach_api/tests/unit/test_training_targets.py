from app.modules.training.service import (
  build_training_session_metadata,
  resolve_training_runtime,
)
from app.modules.training.targets import canonical_training_target


def test_canonical_training_target_resolves_movabled_do_consistently():
  target = canonical_training_target(
    target_id="stage_do",
    solfege="Do",
    key="D",
    octave=4,
    start_sec=0.0,
    end_sec=2.5,
    rest_after_sec=0.75,
  )

  assert target == {
    "target_id": "stage_do",
    "solfege": "Do",
    "scale_degree": 1,
    "midi_note": 62,
    "target_frequency_hz": 293.66,
    "key": "D",
    "octave": 4,
    "start_sec": 0.0,
    "end_sec": 2.5,
    "intended_note_duration_sec": 2.5,
    "rest_after_sec": 0.75,
    "target_type": "sustained_note",
    "breath_cue": True,
  }


def test_runtime_plan_contains_target_contract_and_explicit_beginner_rests():
  plan = resolve_training_runtime(
    exercise_id="do_re_mi_basic_ladder",
    difficulty="beginner",
    key="D",
    octave=4,
    duration_sec=20,
  )

  assert plan["pacing_model"] == "guided_note_windows_with_phrase_rests"
  assert "beat accuracy" not in plan["pacing_basis"].lower()
  assert plan["stages"][0]["target"]["target_frequency_hz"] == 293.66
  assert plan["stages"][0]["target"]["scale_degree"] == 1
  assert plan["stages"][0]["target_type"] == "sustained_note"
  assert plan["stages"][0]["rest_after_sec"] > 0
  assert plan["stages"][0]["breath_cue"] is True
  assert plan["stages"][-1]["end_sec"] == 20
  for previous, current in zip(plan["stages"], plan["stages"][1:]):
    assert current["start_sec"] >= previous["end_sec"]


def test_canonical_target_supports_high_do_and_breathing_phases():
  high_do = canonical_training_target(
    target_id="stage_high_do",
    solfege="Do′",
    key="C",
    octave=4,
    start_sec=0,
    end_sec=1,
    rest_after_sec=0,
  )
  breathing = canonical_training_target(
    target_id="phase_inhale",
    solfege="Inhale",
    key="C",
    octave=4,
    start_sec=0,
    end_sec=1,
    rest_after_sec=0,
  )

  assert high_do["scale_degree"] == 8
  assert high_do["midi_note"] == 72
  assert high_do["target_frequency_hz"] == 523.25
  assert breathing["target_type"] == "breathing_phase"
  assert breathing["target_frequency_hz"] is None
  assert breathing["scale_degree"] is None


def test_beginner_can_choose_a_short_phrase_and_slower_guided_pace():
  metadata = build_training_session_metadata(
    exercise_id="do_re_mi_basic_ladder",
    training_config={
      "difficulty": "beginner",
      "key": "C",
      "octave": 4,
      "pace": "slow",
      "phrase_mode": "short",
    },
  )

  assert metadata["training_config"]["pace"] == "slow"
  assert metadata["training_config"]["phrase_mode"] == "short"
  assert metadata["runtime_plan"]["total_duration_sec"] == 25
  assert metadata["runtime_plan"]["phrase_mode"] == "short"
  assert [stage["target_label"] for stage in metadata["runtime_plan"]["stages"]] == [
    "Do",
    "Re",
    "Mi",
  ]
  assert "slower" in metadata["runtime_plan"]["pacing_basis"].lower()


def test_unknown_pacing_options_fall_back_to_safe_defaults():
  metadata = build_training_session_metadata(
    exercise_id="do_re_mi_basic_ladder",
    training_config={
      "difficulty": "beginner",
      "pace": "rushed",
      "phrase_mode": "all_notes_now",
    },
  )

  assert metadata["training_config"]["pace"] == "standard"
  assert metadata["training_config"]["phrase_mode"] == "full"
  assert len(metadata["runtime_plan"]["stages"]) == 5


def test_short_phrase_keeps_the_exercise_authored_targets():
  metadata = build_training_session_metadata(
    exercise_id="do_re_mi_interval_jumps",
    training_config={
      "difficulty": "beginner",
      "phrase_mode": "short",
    },
  )

  assert [stage["target_label"] for stage in metadata["runtime_plan"]["stages"]] == [
    "Do",
    "Mi",
    "Do",
  ]
  assert "Do, Mi, Do" in metadata["runtime_plan"]["summary"]
