import json
from hashlib import sha256

import pytest

from ..karaoke_pipeline import SongSpec
from ..karaoke_publisher import (
  PublishError,
  build_cloudinary_signature,
  load_publish_artifacts,
  publish_song,
)


def _spec() -> SongSpec:
  return SongSpec(
    drill_id="gospel_breathe_hillsong_kids",
    title="Breathe",
    artist="Hillsong Kids",
    catalog_code="12179",
    catalog_volume="59",
    source_url="https://www.youtube.com/watch?v=Rh8fDZhIqyc",
    rights_confirmed=True,
    source_status="candidate_official_upload",
    analysis_min_hz=65.0,
    analysis_max_hz=1046.5,
  )


def _write_assets(tmp_path, *, status="approved_for_publication", kind="reviewed_target_contour"):
  asset_dir = tmp_path / _spec().drill_id
  asset_dir.mkdir(exist_ok=True)
  audio = asset_dir / "instrumental.mp3"
  pitch_map = asset_dir / "pitch_map.json"
  audio.write_bytes(b"audio")
  pitch_map.write_text(
    json.dumps([
      {"time": 0.0, "pitch": 261.63},
      {"time": 0.5, "pitch": 293.66},
    ]),
    encoding="utf-8",
  )
  metadata = {
    "schema_version": 1,
    "drill_id": _spec().drill_id,
    "title": _spec().title,
    "artist": _spec().artist,
    "rights_confirmed": True,
    "pitch_map_kind": kind,
    "publish_status": status,
    "audio_sha256": sha256(audio.read_bytes()).hexdigest(),
    "pitch_map_sha256": sha256(pitch_map.read_bytes()).hexdigest(),
  }
  (asset_dir / "metadata.json").write_text(json.dumps(metadata), encoding="utf-8")


def test_cloudinary_signature_is_deterministic_and_sorted() -> None:
  params = {"timestamp": 1700000000, "folder": "karaoke/test", "overwrite": "false"}

  first = build_cloudinary_signature(params, "secret")
  second = build_cloudinary_signature(dict(reversed(list(params.items()))), "secret")

  assert first == second
  assert len(first) == 40


def test_cloudinary_signature_matches_documented_minimal_example() -> None:
  assert build_cloudinary_signature({"timestamp": 1315060510}, "abcd") == (
    "a21ad0f63beb4de2e5575204b79ab90bffb02c10"
  )


def test_artifacts_require_review_and_target_map(tmp_path) -> None:
  _write_assets(tmp_path, status="local_review_required")

  with pytest.raises(PublishError, match="not approved"):
    load_publish_artifacts(_spec(), tmp_path)

  _write_assets(tmp_path, kind="observed_vocal_contour")
  with pytest.raises(PublishError, match="target contour"):
    load_publish_artifacts(_spec(), tmp_path)


def test_publish_uploads_both_assets_before_updating_catalog(tmp_path) -> None:
  _write_assets(tmp_path)

  class FakeUploader:
    def __init__(self):
      self.calls = []

    def upload(self, path, *, resource_type, public_id, format_name, overwrite):
      self.calls.append((path.name, resource_type, public_id, format_name, overwrite))
      return {"secure_url": f"https://cdn.example/{path.name}"}

  class FakeWriter:
    def __init__(self):
      self.calls = []

    def update_urls(self, drill_id, *, instrumental_url, pitch_map_url, metadata):
      self.calls.append((drill_id, instrumental_url, pitch_map_url, metadata))

  uploader = FakeUploader()
  writer = FakeWriter()

  result = publish_song(_spec(), tmp_path, uploader=uploader, writer=writer)

  assert [call[0] for call in uploader.calls] == ["instrumental.mp3", "pitch_map.json"]
  assert all(call[4] is False for call in uploader.calls)
  assert writer.calls[0][0] == _spec().drill_id
  assert result["instrumental_url"].endswith("instrumental.mp3")
  assert result["pitch_map_url"].endswith("pitch_map.json")


def test_publish_does_not_update_catalog_when_second_upload_fails(tmp_path) -> None:
  _write_assets(tmp_path)

  class FailingUploader:
    def upload(self, path, **_kwargs):
      if path.name == "pitch_map.json":
        raise PublishError("Cloudinary upload failed")
      return {"secure_url": "https://cdn.example/instrumental.mp3"}

  class FakeWriter:
    called = False

    def update_urls(self, *_args, **_kwargs):
      self.called = True

  writer = FakeWriter()

  with pytest.raises(PublishError, match="Cloudinary upload failed"):
    publish_song(_spec(), tmp_path, uploader=FailingUploader(), writer=writer)

  assert writer.called is False
