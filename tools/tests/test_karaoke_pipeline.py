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
