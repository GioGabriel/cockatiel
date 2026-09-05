from app.modules.training.catalog import default_attempt_policy, get_exercise


def test_training_catalog_hierarchy(client, auth_headers):
  response = client.get("/v1/training/catalog", headers=auth_headers)
  assert response.status_code == 200

  payload = response.json()
  assert payload["module_id"] == "vocal_coach"

  categories = payload["categories"]
  category_ids = {item["category_id"] for item in categories}
  assert category_ids == {"vocal_training", "do_re_mi", "breathing"}

  vocal_training = next(item for item in categories if item["category_id"] == "vocal_training")
  resonance = next(
    item for item in vocal_training["exercises"] if item["exercise_id"] == "resonance_placement"
  )
  assert resonance["objective"]
  assert resonance["what_you_do"]
  assert resonance["requires_microphone"] is True
  assert resonance["exercise_mode"] == "voice"
  assert resonance["focus_metrics"] == ["breath_control", "pitch_stability", "pitch_accuracy"]
  assert resonance["patterns_by_difficulty"]["beginner"]["pattern_type"] == "sustain"

  do_re_mi = next(item for item in categories if item["category_id"] == "do_re_mi")
  basic_ladder = next(
    item for item in do_re_mi["exercises"] if item["exercise_id"] == "do_re_mi_basic_ladder"
  )
  assert [stage["target_label"] for stage in basic_ladder["patterns_by_difficulty"]["beginner"]["stages"]] == [
    "Do",
    "Re",
    "Mi",
    "Fa",
    "Sol",
  ]
  interval_jumps = next(
    item for item in do_re_mi["exercises"] if item["exercise_id"] == "do_re_mi_interval_jumps"
  )
  assert interval_jumps["patterns_by_difficulty"]["advanced"]["pattern_type"] == "jump"

  breathing = next(item for item in categories if item["category_id"] == "breathing")
  support_ladder = next(
    item for item in breathing["exercises"] if item["exercise_id"] == "breath_support_ladder"
  )
  assert support_ladder["requires_microphone"] is False
  assert support_ladder["exercise_mode"] == "breathing_timer"
  assert support_ladder["focus_metrics"] == [
    "phase_completion_rate",
    "pace_adherence",
    "cycle_consistency",
  ]
  assert support_ladder["patterns_by_difficulty"]["beginner"]["stages"][0]["target_label"] == "Inhale"
  assert support_ladder["patterns_by_difficulty"]["intermediate"]["pattern_type"] == "breathing"


def test_training_progress_and_recommendations(client, auth_headers):
  progress_response = client.get("/v1/training/progress", headers=auth_headers)
  assert progress_response.status_code == 200
  assert progress_response.json()["items"] == []

  recommendation_response = client.get("/v1/training/recommendations", headers=auth_headers)
  assert recommendation_response.status_code == 200
  items = recommendation_response.json()["items"]
  assert len(items) == 3
  assert all("exercise_id" in item for item in items)


def test_training_session_rejects_unknown_exercise(client, auth_headers):
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={"mode": "training", "exercise_type": "unknown_exercise"},
  )

  assert response.status_code == 400
  assert response.json()["error"]["code"] == "TRAINING_EXERCISE_NOT_FOUND"


def test_training_session_stores_category_and_config(client, auth_headers):
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={
      "mode": "training",
      "exercise_type": "resonance_placement",
      "training_config": {
        "difficulty": "intermediate",
        "key": "D",
        "octave": 4,
      },
    },
  )
  assert response.status_code == 201
  session_id = response.json()["session_id"]

  session_response = client.get(f"/v1/sessions/{session_id}", headers=auth_headers)
  assert session_response.status_code == 200
  session_payload = session_response.json()
  assert session_payload["category_id"] == "vocal_training"
  assert session_payload["exercise_id"] == "resonance_placement"
  assert session_payload["training_config"]["difficulty"] == "intermediate"
  assert session_payload["training_config"]["duration_sec"] == 30
  assert session_payload["training_config"]["max_attempts"] == 3
  assert session_payload["exercise_spec"]["objective"]
  assert session_payload["exercise_spec"]["what_you_do"]
  assert session_payload["runtime_plan"]["pattern_type"] == "sustain"
  assert "anchor tones" in session_payload["runtime_plan"]["teaching_note"]
  assert session_payload["runtime_plan"]["total_duration_sec"] == 30
  assert session_payload["runtime_plan"]["stages"][0]["target_label"] == "Do"


def test_do_re_mi_session_resolves_jump_runtime_plan(client, auth_headers):
  response = client.post(
    "/v1/sessions",
    headers=auth_headers,
    json={
      "mode": "training",
      "exercise_type": "do_re_mi_interval_jumps",
      "training_config": {
        "difficulty": "advanced",
        "key": "G",
        "octave": 4,
      },
    },
  )
  assert response.status_code == 201
  session_id = response.json()["session_id"]

  session_response = client.get(f"/v1/sessions/{session_id}", headers=auth_headers)
  assert session_response.status_code == 200
  session_payload = session_response.json()
  assert session_payload["category_id"] == "do_re_mi"
  assert session_payload["runtime_plan"]["pattern_type"] == "jump"
  assert session_payload["runtime_plan"]["key"] == "G"
  assert session_payload["runtime_plan"]["stages"][0]["target_label"] == "Do"


def test_training_catalog_explains_scale_and_interval_patterns():
  ladder = get_exercise("do_re_mi_basic_ladder")
  interval = get_exercise("do_re_mi_interval_jumps")
  placement = get_exercise("resonance_placement")

  assert ladder is not None
  assert interval is not None
  assert placement is not None

  ladder_pattern = ladder["patterns_by_difficulty"]["beginner"]
  interval_pattern = interval["patterns_by_difficulty"]["beginner"]
  placement_pattern = placement["patterns_by_difficulty"]["beginner"]

  assert ladder_pattern["teaching_note"] == (
    "This is the complete beginner scale: Do, Re, Mi, Fa, Sol."
  )
  assert "intentionally skip" in interval_pattern["teaching_note"]
  assert "anchor tones" in placement_pattern["teaching_note"]


def test_beginner_warmup_uses_the_complete_five_note_ladder():
  exercise = get_exercise("warmup_pitch")

  assert exercise is not None
  pattern = exercise["patterns_by_difficulty"]["beginner"]
  assert [stage["target_label"] for stage in pattern["stages"]] == [
    "Do",
    "Re",
    "Mi",
    "Fa",
    "Sol",
  ]


def test_training_duration_policy_is_short_and_repeatable():
  policy = default_attempt_policy()

  assert policy["duration_sec_by_difficulty"] == {
    "beginner": 20,
    "intermediate": 30,
    "advanced": 45,
  }
