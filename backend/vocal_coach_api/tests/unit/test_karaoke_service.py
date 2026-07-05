"""Unit tests for the karaoke catalog and service module."""
import os

os.environ["AUTH_BYPASS"] = "true"
os.environ["FIRESTORE_ENABLED"] = "false"
os.environ["OLLAMA_ENABLED"] = "false"
os.environ["AUDIO_SNIPPET_STORAGE_BACKEND"] = "local"
os.environ["AUDIO_SNIPPET_LOCAL_DIR"] = "/tmp/vocal-coach-audio-test"
os.environ["AUDIO_SNIPPET_RETENTION_DAYS"] = "30"

from app.modules.karaoke.service import get_karaoke_catalog, get_drill_by_id, get_catalog_preview


class TestKaraokeCatalogStructure:
  def test_catalog_has_minimum_3_categories(self) -> None:
    catalog = get_karaoke_catalog()
    assert len(catalog["categories"]) >= 3

  def test_categories_have_distinct_style_labels(self) -> None:
    catalog = get_karaoke_catalog()
    labels = [c["style_label"] for c in catalog["categories"]]
    assert len(labels) == len(set(labels))

  def test_each_category_has_at_least_one_drill(self) -> None:
    catalog = get_karaoke_catalog()
    for cat in catalog["categories"]:
      assert len(cat["drills"]) >= 1, f"Category {cat['category_id']} has no drills"


class TestKaraokeDrillMetadata:
  def test_all_drills_have_required_fields(self) -> None:
    catalog = get_karaoke_catalog()
    required = {"drill_id", "title", "style_category", "difficulty",
                "duration_sec", "tempo_bpm", "vocal_range", "objective",
                "performance_tips", "melody_reference"}
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert required.issubset(drill.keys()), f"Drill {drill.get('drill_id')} missing fields"

  def test_duration_within_bounds(self) -> None:
    catalog = get_karaoke_catalog()
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert 30 <= drill["duration_sec"] <= 180

  def test_tempo_within_bounds(self) -> None:
    catalog = get_karaoke_catalog()
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert 40 <= drill["tempo_bpm"] <= 220

  def test_vocal_range_has_low_and_high(self) -> None:
    catalog = get_karaoke_catalog()
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert "low" in drill["vocal_range"]
        assert "high" in drill["vocal_range"]

  def test_performance_tips_non_empty(self) -> None:
    catalog = get_karaoke_catalog()
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert len(drill["performance_tips"]) >= 1

  def test_melody_reference_non_empty(self) -> None:
    catalog = get_karaoke_catalog()
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert len(drill["melody_reference"]) >= 1

  def test_difficulty_values_valid(self) -> None:
    catalog = get_karaoke_catalog()
    valid = {"beginner", "intermediate", "advanced"}
    for cat in catalog["categories"]:
      for drill in cat["drills"]:
        assert drill["difficulty"] in valid


class TestGetDrillById:
  def test_returns_drill_for_valid_id(self) -> None:
    drill = get_drill_by_id("pop_breath_control_1")
    assert drill is not None
    assert drill["drill_id"] == "pop_breath_control_1"

  def test_returns_none_for_unknown_id(self) -> None:
    assert get_drill_by_id("nonexistent") is None


class TestCatalogPreview:
  def test_preview_has_expected_structure(self) -> None:
    preview = get_catalog_preview()
    assert "module_id" in preview
    assert "category_count" in preview
    assert "total_drills" in preview
    assert "categories" in preview
    assert preview["category_count"] >= 3
    assert preview["total_drills"] >= 3

  def test_preview_categories_have_drill_count(self) -> None:
    preview = get_catalog_preview()
    for cat in preview["categories"]:
      assert "category_id" in cat
      assert "style_label" in cat
      assert "drill_count" in cat
      assert cat["drill_count"] >= 1
