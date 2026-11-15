import json
from pathlib import Path

import pytest

from ..karaoke_pipeline import (
  ManifestError,
  _ensure_reusable_directory,
  load_manifest_data,
  sanitize_pitch_points,
  summarize_pitch_points,
)


def _song(**overrides: object) -> dict[str, object]:
  song = {
    "drill_id": "gospel_breathe_hillsong_kids",
    "title": "Breathe",
    "artist": "Hillsong Kids",
    "catalog_code": "12179",
    "catalog_volume": "59",
    "source_url": "https://www.youtube.com/watch?v=Rh8fDZhIqyc",
    "rights_confirmed": True,
  }
  song.update(overrides)
  return song


def test_manifest_requires_unique_ids_and_https_youtube_sources() -> None:
  manifest = {"schema_version": 1, "rights_confirmed": True, "songs": [_song()]}

  specs = load_manifest_data(manifest)

  assert len(specs) == 1
  assert specs[0].drill_id == "gospel_breathe_hillsong_kids"
  assert specs[0].source_url.endswith("Rh8fDZhIqyc")

  with pytest.raises(ManifestError, match="duplicate drill_id"):
    load_manifest_data({**manifest, "songs": [_song(), _song(title="Other")]})

  with pytest.raises(ManifestError, match="HTTPS YouTube URL"):
    load_manifest_data({**manifest, "songs": [_song(source_url="http://example.com/audio")]})

  with pytest.raises(ManifestError, match="video ID"):
    load_manifest_data(
      {
        **manifest,
        "songs": [_song(source_url="https://www.youtube.com/watch?list=playlist")],
      }
    )


def test_manifest_rejects_unconfirmed_rights_for_processing() -> None:
  with pytest.raises(ManifestError, match="rights_confirmed"):
    load_manifest_data(
      {
        "schema_version": 1,
        "rights_confirmed": False,
        "songs": [_song(rights_confirmed=False)],
      }
    )


def test_manifest_allows_unresolved_entries_without_a_source() -> None:
  specs = load_manifest_data(
    {
      "schema_version": 1,
      "rights_confirmed": True,
      "songs": [_song(source_url=None, source_status="needs_source")],
    }
  )

  assert specs[0].source_url is None
  assert specs[0].source_status == "needs_source"


def test_pitch_points_drop_invalid_values_and_low_confidence() -> None:
  points = sanitize_pitch_points(
    [
      {"time": 0.0, "pitch": 220.0, "confidence": 0.95},
      {"time": 0.1, "pitch": 0.0, "confidence": 0.99},
      {"time": 0.2, "pitch": 440.0, "confidence": 0.40},
      {"time": 0.3, "pitch": 9999.0, "confidence": 0.99},
      {"time": 0.4, "pitch": 246.94, "confidence": 0.90},
      {"time": 0.4, "pitch": 246.94, "confidence": 0.90},
    ],
    min_frequency_hz=65.0,
    max_frequency_hz=1046.5,
    min_confidence=0.75,
  )

  assert points == [
    {"time": 0.0, "pitch": 220.0, "confidence": 0.95},
    {"time": 0.4, "pitch": 246.94, "confidence": 0.9},
  ]


def test_pitch_summary_reports_usable_evidence_without_calling_it_a_key_map() -> None:
  points = [
    {"time": 0.0, "pitch": 220.0, "confidence": 0.95},
    {"time": 0.5, "pitch": 246.94, "confidence": 0.90},
  ]

  summary = summarize_pitch_points(points, audio_duration_sec=2.0)

  assert summary["point_count"] == 2
  assert summary["coverage_ratio"] == 0.25
  assert summary["min_pitch_hz"] == 220.0
  assert summary["max_pitch_hz"] == 246.94
  assert summary["pitch_map_kind"] == "observed_vocal_contour"


def test_empty_staging_directory_can_be_reused_after_a_failed_attempt(tmp_path) -> None:
  staging = tmp_path / "staging"
  staging.mkdir()

  _ensure_reusable_directory(staging)

  assert staging.is_dir()


def test_nonempty_staging_directory_is_never_overwritten(tmp_path) -> None:
  staging = tmp_path / "staging"
  staging.mkdir()
  (staging / "partial.download").write_bytes(b"partial")

  with pytest.raises(FileExistsError, match="contains files"):
    _ensure_reusable_directory(staging)


def test_requested_gospel_catalog_entries_match_the_supplied_list() -> None:
  repo_root = Path(__file__).resolve().parents[2]
  manifest = json.loads((repo_root / "scratch/karaoke_gospel_manifest.json").read_text(encoding="utf-8"))
  specs = load_manifest_data(manifest)
  by_id = {spec.drill_id: spec for spec in specs}
  expected = {
    "gospel_glorify_your_name_hillsong_australia": ("Glorify Your Name", "Hillsong Worship", "12347"),
    "gospel_glory_hillsong_australia": ("Glory", "Hillsong Worship", "12350"),
    "gospel_all_for_love_hillsong_united": ("All For Love", "Hillsong UNITED", "18682"),
    "gospel_hosanna_hillsong_united": ("Hosanna", "Hillsong UNITED", "27059"),
    "gospel_lead_me_to_the_cross_hillsong_united": ("Lead Me to the Cross", "Hillsong UNITED", "27121"),
    "gospel_oceans_hillsong_united": ("Oceans (Where Feet May Fail)", "Hillsong UNITED", "16223"),
  }

  assert manifest["rights_confirmed"] is True
  assert set(expected).issubset(by_id)
  for drill_id, (title, artist, catalog_code) in expected.items():
    spec = by_id[drill_id]
    assert (spec.title, spec.artist, spec.catalog_code) == (title, artist, catalog_code)
    assert spec.rights_confirmed is True
    assert spec.source_url is not None


@pytest.mark.parametrize(
  "drill_id,artist,video_id",
  [
    ("gospel_jesus_generation_hillsong_australia", "Hillsong UNITED", "urrrRyBG5l0"),
    ("gospel_a_broken_spirit_don_harris_martin_j", "Martin J. Nystrom", "zSUaenj8_r0"),
    ("gospel_a_heart_like_mine_bryan_duncan", "Bryan Duncan", "oDjxd3yh6OQ"),
    ("gospel_a_man_after_your_own_heart_wayne_kirkpatrick", "Gary Chapman", "cSjv1DJtLDE"),
    ("gospel_a_place_at_your_altar_gerrit_gustafson", "Randy Rothwell", "zs_b7ckCbFE"),
    ("gospel_a_pure_heart_rusty_nelson", "Rusty Nelson", "rrNwrs7pGZc"),
  ],
)
def test_new_recordings_attribute_performers_and_retain_source_evidence(drill_id, artist, video_id) -> None:
  repo_root = Path(__file__).resolve().parents[2]
  manifest = json.loads((repo_root / "scratch/karaoke_gospel_manifest.json").read_text(encoding="utf-8"))
  specs = {spec.drill_id: spec for spec in load_manifest_data(manifest)}
  raw = next(song for song in manifest["songs"] if song["drill_id"] == drill_id)

  assert specs[drill_id].artist == artist
  assert specs[drill_id].source_url == f"https://www.youtube.com/watch?v={video_id}"
  assert specs[drill_id].source_status == "verified_official_recording"
  assert raw["source_review"]["recording_title"]
  assert raw["source_review"]["album"]
  assert 10 <= raw["source_review"]["duration_sec"] <= 600
  assert raw["source_review"]["reviewed_on"] == "2026-11-15"
