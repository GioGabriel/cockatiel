import json
import io
from hashlib import sha256
from urllib.error import HTTPError

import pytest

from .. import karaoke_publisher as publisher_module
from ..karaoke_pipeline import SongSpec
from ..karaoke_publisher import (
  CloudinaryUploader,
  FirestoreCatalogWriter,
  PublishError,
  build_cloudinary_signature,
  build_catalog_document,
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


def _write_assets(
  tmp_path,
  *,
  status="approved_for_publication",
  kind="reviewed_target_contour",
  approval_basis=None,
):
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
  if approval_basis is not None:
    metadata["approval_basis"] = approval_basis
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


def test_cloudinary_http_error_reports_status_without_response_body(monkeypatch, tmp_path) -> None:
  audio = tmp_path / "instrumental.mp3"
  audio.write_bytes(b"audio")
  uploader = CloudinaryUploader("cloud", "api-key", "api-secret")

  def fail_upload(*_args, **_kwargs):
    raise HTTPError(
      "https://api.cloudinary.com/upload",
      401,
      "Unauthorized",
      hdrs=None,
      fp=io.BytesIO(b'{"api_key":"do-not-print"}'),
    )

  monkeypatch.setattr(publisher_module, "urlopen", fail_upload)
  with pytest.raises(PublishError, match="HTTP 401") as error:
    uploader.upload(
      audio,
      resource_type="video",
      public_id="test/instrumental",
      format_name="mp3",
      overwrite=False,
    )
  assert "do-not-print" not in str(error.value)


def test_artifacts_require_review_and_target_map(tmp_path) -> None:
  _write_assets(tmp_path, status="local_review_required")

  with pytest.raises(PublishError, match="not approved"):
    load_publish_artifacts(_spec(), tmp_path)

  _write_assets(tmp_path, kind="observed_vocal_contour")
  with pytest.raises(PublishError, match="explicit publication approval"):
    load_publish_artifacts(_spec(), tmp_path)

  _write_assets(
    tmp_path,
    kind="observed_vocal_contour",
    approval_basis="explicit_user_publication_authorization",
  )
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


def test_catalog_document_contains_complete_runtime_metadata(tmp_path) -> None:
  _write_assets(tmp_path)
  metadata_path = tmp_path / _spec().drill_id / "metadata.json"
  metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
  metadata.update(
    {
      "difficulty": "beginner",
      "tempo_bpm": 120,
      "pitch_analysis": {
        "audio_duration_sec": 12.0,
        "min_pitch_hz": 261.63,
        "max_pitch_hz": 293.66,
      },
    }
  )
  metadata_path.write_text(json.dumps(metadata), encoding="utf-8")

  artifacts = load_publish_artifacts(_spec(), tmp_path)
  document = build_catalog_document(
    _spec(),
    artifacts,
    instrumental_url="https://cdn.example/instrumental.mp3",
    pitch_map_url="https://cdn.example/pitch_map.json",
  )

  assert document["drill_id"] == _spec().drill_id
  assert document["duration_sec"] == 12
  assert document["tempo_bpm"] == 120
  assert document["vocal_range"] == {"low": "C4", "high": "D4"}
  assert document["instrumental_url"].endswith("instrumental.mp3")
  assert document["pitch_map_url"].endswith("pitch_map.json")
  assert document["melody_reference"]
  assert {note["note"] for note in document["melody_reference"]} == {"C4", "D4"}


def test_firestore_writer_creates_complete_document_only_when_explicitly_allowed() -> None:
  class MissingSnapshot:
    exists = False

  class FakeDocument:
    def __init__(self):
      self.created = None
      self.updated = None

    def get(self):
      return MissingSnapshot()

    def create(self, payload):
      self.created = payload

    def update(self, payload):
      self.updated = payload

  class FakeCollection:
    def __init__(self):
      self.document_ref = FakeDocument()

    def document(self, _drill_id):
      return self.document_ref

  class FakeDatabase:
    def __init__(self):
      self.collection_ref = FakeCollection()

    def collection(self, _name):
      return self.collection_ref

  database = FakeDatabase()
  writer = FirestoreCatalogWriter(database)
  catalog_document = {
    "drill_id": "gospel_breathe_hillsong_kids",
    "title": "Breathe",
    "style_category": "Gospel",
    "difficulty": "beginner",
    "duration_sec": 12,
    "tempo_bpm": 120,
    "vocal_range": {"low": "C4", "high": "D4"},
    "objective": "Match the reference contour.",
    "performance_tips": ["Stay relaxed."],
    "melody_reference": [{"note": "C4", "start_beat": 0.0, "duration_beats": 4.0}],
    "instrumental_url": "",
    "pitch_map_url": "",
    "artist_name": "Hillsong Kids",
    "cover_url": "",
  }

  with pytest.raises(PublishError, match="missing.*--create-missing"):
    writer.update_urls(
      catalog_document["drill_id"],
      instrumental_url="https://cdn.example/instrumental.mp3",
      pitch_map_url="https://cdn.example/pitch_map.json",
      metadata={"audio_sha256": "audio", "pitch_map_sha256": "pitch"},
    )

  writer.create_or_update(
    catalog_document["drill_id"],
    instrumental_url="https://cdn.example/instrumental.mp3",
    pitch_map_url="https://cdn.example/pitch_map.json",
    metadata={"audio_sha256": "audio", "pitch_map_sha256": "pitch"},
    catalog_document=catalog_document,
  )

  assert database.collection_ref.document_ref.created["title"] == "Breathe"
  assert database.collection_ref.document_ref.created["instrumental_url"].endswith("instrumental.mp3")
  assert database.collection_ref.document_ref.created["content_revision"] == "audio"
