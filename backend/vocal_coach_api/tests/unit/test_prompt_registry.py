from app.ai_engine.prompt_management.registry.service import resolve_feedback_prompts


def test_prompt_registry_falls_back_to_v1_for_unknown_version():
  system_prompt, user_prompt, resolved_version = resolve_feedback_prompts(
    prompt_version="v999",
    session_id="abc",
    exercise_type="warmup_pitch",
    overall_score=70,
    metric_summary={"pitch_accuracy": 70},
  )

  assert resolved_version == "v1"
  assert "Return only JSON" in system_prompt
  assert "session_id=abc" in user_prompt


def test_prompt_registry_accepts_explicit_v1a_version():
  _, user_prompt, resolved_version = resolve_feedback_prompts(
    prompt_version="v1a",
    session_id="abc",
    exercise_type="karaoke",
    overall_score=77,
    metric_summary={"timing_accuracy": 77},
  )

  assert resolved_version == "v1a"
  assert "karaoke" in user_prompt.lower()


def test_prompt_registry_ab_switch_is_deterministic_for_same_session_id():
  _, _, resolved_one = resolve_feedback_prompts(
    prompt_version="ab",
    session_id="deterministic-session",
    exercise_type="warmup_pitch",
    overall_score=65,
    metric_summary={"pitch_accuracy": 65},
  )
  _, _, resolved_two = resolve_feedback_prompts(
    prompt_version="ab",
    session_id="deterministic-session",
    exercise_type="warmup_pitch",
    overall_score=65,
    metric_summary={"pitch_accuracy": 65},
  )

  assert resolved_one in {"v1a", "v1b"}
  assert resolved_two == resolved_one


def test_prompt_registry_includes_session_context_when_provided():
  _, user_prompt, _ = resolve_feedback_prompts(
    prompt_version="v1",
    session_id="context-session",
    exercise_type="resonance_placement",
    overall_score=82,
    metric_summary={"pitch_accuracy": 82},
    session_context={"exercise_name": "Resonance Placement", "difficulty": "beginner"},
  )

  assert 'session_context={"difficulty": "beginner", "exercise_name": "Resonance Placement"}' in user_prompt
