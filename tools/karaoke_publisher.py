"""Publish reviewed karaoke assets to Cloudinary and existing Firestore records.

This is an explicit, one-shot operator tool. It never downloads source media,
creates incomplete catalog documents, prints credentials, or changes a catalog
record until both deterministic Cloudinary assets have been uploaded.

The process needs these environment variables only when ``publish`` is run:

* ``CLOUDINARY_CLOUD_NAME``
* ``CLOUDINARY_API_KEY``
* ``CLOUDINARY_API_SECRET``

Firebase Admin uses its normal application-default credential configuration.
The tool is intentionally separate from the web service so a normal API
request can never publish arbitrary files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sys
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

if __package__ in {None, ""}:  # pragma: no cover - direct CLI execution
  sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tools.karaoke_pipeline import SongSpec, load_manifest


class PublishError(RuntimeError):
  """Raised when an asset fails the publication gate or an external write fails."""


class AssetUploader(Protocol):
  def upload(
    self,
    path: Path,
    *,
    resource_type: str,
    public_id: str,
    format_name: str | None,
    overwrite: bool,
  ) -> Mapping[str, Any]: ...


class CatalogWriter(Protocol):
  def update_urls(
    self,
    drill_id: str,
    *,
    instrumental_url: str,
    pitch_map_url: str,
    metadata: Mapping[str, Any],
  ) -> None: ...


@dataclass(frozen=True)
class PublishArtifacts:
  directory: Path
  instrumental_path: Path
  pitch_map_path: Path
  metadata_path: Path
  metadata: Mapping[str, Any]


_CLOUD_NAME_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
_MAX_PITCH_POINTS = 250_000


def _sha256(path: Path) -> str:
  digest = hashlib.sha256()
  with path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
      digest.update(chunk)
  return digest.hexdigest()


def _finite(value: object, field: str) -> float:
  if isinstance(value, bool):
    raise PublishError(f"pitch map field {field} must be finite")
  try:
    number = float(value)
  except (TypeError, ValueError) as exc:
    raise PublishError(f"pitch map field {field} must be finite") from exc
  if not math.isfinite(number):
    raise PublishError(f"pitch map field {field} must be finite")
  return number


def build_cloudinary_signature(parameters: Mapping[str, object], api_secret: str) -> str:
  """Create the SHA-1 upload signature without exposing the secret."""
  if not api_secret.strip():
    raise PublishError("CLOUDINARY_API_SECRET is missing")
  canonical = "&".join(
    f"{key}={value}"
    for key, value in sorted(
      ((str(key), str(value)) for key, value in parameters.items() if value is not None),
      key=lambda item: item[0],
    )
  )
  return hashlib.sha1(f"{canonical}{api_secret}".encode()).hexdigest()


def _multipart_form(
  fields: Mapping[str, str],
  *,
  file_field: str,
  filename: str,
  file_bytes: bytes,
) -> tuple[bytes, str]:
  boundary = f"----cockatiel-{hashlib.sha256(file_bytes[:4096]).hexdigest()[:24]}"
  chunks: list[bytes] = []
  for name, value in fields.items():
    chunks.extend(
      [
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
        value.encode("utf-8"),
        b"\r\n",
      ]
    )
  chunks.extend(
    [
      f"--{boundary}\r\n".encode(),
      f'Content-Disposition: form-data; name="{file_field}"; filename="{filename}"\r\n'.encode(),
      b"Content-Type: application/octet-stream\r\n\r\n",
      file_bytes,
      b"\r\n",
      f"--{boundary}--\r\n".encode(),
    ]
  )
  return b"".join(chunks), boundary


class CloudinaryUploader:
  """Small signed-upload client with no third-party runtime dependency."""

  def __init__(self, cloud_name: str, api_key: str, api_secret: str, *, timeout_sec: float = 60.0) -> None:
    if not _CLOUD_NAME_RE.fullmatch(cloud_name):
      raise PublishError("CLOUDINARY_CLOUD_NAME is invalid")
    if not api_key.strip():
      raise PublishError("CLOUDINARY_API_KEY is missing")
    if not api_secret.strip():
      raise PublishError("CLOUDINARY_API_SECRET is missing")
    self._cloud_name = cloud_name
    self._api_key = api_key
    self._api_secret = api_secret
    self._timeout_sec = timeout_sec

  @classmethod
  def from_environment(cls, environ: Mapping[str, str] | None = None) -> CloudinaryUploader:
    values = os.environ if environ is None else environ
    return cls(
      values.get("CLOUDINARY_CLOUD_NAME", "").strip(),
      values.get("CLOUDINARY_API_KEY", "").strip(),
      values.get("CLOUDINARY_API_SECRET", "").strip(),
    )

  def upload(
    self,
    path: Path,
    *,
    resource_type: str,
    public_id: str,
    format_name: str | None,
    overwrite: bool,
  ) -> Mapping[str, Any]:
    timestamp = int(time.time())
    fields: dict[str, str] = {
      "api_key": self._api_key,
      "overwrite": "true" if overwrite else "false",
      "public_id": f"cockatiel/karaoke/{public_id}",
      "timestamp": str(timestamp),
    }
    if format_name:
      fields["format"] = format_name
    signature_parameters = {key: value for key, value in fields.items() if key != "api_key"}
    fields["signature"] = build_cloudinary_signature(signature_parameters, self._api_secret)
    body, boundary = _multipart_form(
      fields,
      file_field="file",
      filename=path.name,
      file_bytes=path.read_bytes(),
    )
    endpoint = f"https://api.cloudinary.com/v1_1/{self._cloud_name}/{resource_type}/upload"
    request = Request(
      endpoint,
      data=body,
      method="POST",
      headers={
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Accept": "application/json",
      },
    )
    try:
      with urlopen(request, timeout=self._timeout_sec) as response:
        payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
      raise PublishError(f"Cloudinary {resource_type} upload failed") from exc
    if not isinstance(payload, Mapping):
      raise PublishError(f"Cloudinary {resource_type} upload returned an invalid response")
    secure_url = payload.get("secure_url")
    if not isinstance(secure_url, str) or not secure_url.startswith("https://"):
      raise PublishError(f"Cloudinary {resource_type} upload returned no secure URL")
    return {"secure_url": secure_url, "public_id": str(payload.get("public_id") or public_id)}


class FirestoreCatalogWriter:
  """Update only an existing catalog document; never create an incomplete one."""

  def __init__(self, database: Any) -> None:
    self._database = database

  @classmethod
  def from_application_default_credentials(cls) -> FirestoreCatalogWriter:
    try:
      import firebase_admin
      from firebase_admin import firestore
    except ImportError as exc:  # pragma: no cover - dependency belongs to Render
      raise PublishError("Firebase Admin SDK is unavailable") from exc

    try:
      firebase_admin.get_app()
    except ValueError:
      try:
        firebase_admin.initialize_app()
      except Exception as exc:  # pragma: no cover - external configuration
        raise PublishError("Firebase Admin credentials are unavailable") from exc
    try:
      return cls(firestore.client())
    except Exception as exc:  # pragma: no cover - external configuration
      raise PublishError("Firestore is unavailable") from exc

  def update_urls(
    self,
    drill_id: str,
    *,
    instrumental_url: str,
    pitch_map_url: str,
    metadata: Mapping[str, Any],
  ) -> None:
    payload = {
      "instrumental_url": instrumental_url,
      "pitch_map_url": pitch_map_url,
      "content_revision": str(metadata.get("audio_sha256") or "")[:16],
      "pitch_map_revision": str(metadata.get("pitch_map_sha256") or "")[:16],
    }
    try:
      self._database.collection("karaoke_songs").document(drill_id).update(payload)
    except Exception as exc:  # pragma: no cover - external Firestore behavior
      raise PublishError("Firestore catalog update failed; no catalog record was changed") from exc


def _read_pitch_map(path: Path) -> None:
  try:
    raw_points = json.loads(path.read_text(encoding="utf-8"))
  except (OSError, json.JSONDecodeError) as exc:
    raise PublishError("pitch_map.json is not valid JSON") from exc
  if not isinstance(raw_points, list) or not raw_points:
    raise PublishError("pitch_map.json must contain a non-empty list")
  if len(raw_points) > _MAX_PITCH_POINTS:
    raise PublishError("pitch_map.json contains too many points")
  previous_time = -1.0
  for index, point in enumerate(raw_points):
    if not isinstance(point, Mapping):
      raise PublishError(f"pitch_map.json point {index} is invalid")
    current_time = _finite(point.get("time"), f"point {index}.time")
    current_pitch = _finite(point.get("pitch"), f"point {index}.pitch")
    if current_time < 0 or current_pitch <= 0:
      raise PublishError(f"pitch_map.json point {index} is out of bounds")
    if current_time < previous_time:
      raise PublishError("pitch_map.json times must be sorted")
    previous_time = current_time


def load_publish_artifacts(spec: SongSpec, assets_root: Path) -> PublishArtifacts:
  directory = assets_root / spec.drill_id
  instrumental_path = directory / "instrumental.mp3"
  pitch_map_path = directory / "pitch_map.json"
  metadata_path = directory / "metadata.json"
  for path in (instrumental_path, pitch_map_path, metadata_path):
    if not path.is_file() or path.stat().st_size == 0:
      raise PublishError(f"missing or empty publication asset: {path.name}")

  try:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
  except (OSError, json.JSONDecodeError) as exc:
    raise PublishError("metadata.json is not valid JSON") from exc
  if not isinstance(metadata, Mapping):
    raise PublishError("metadata.json must contain an object")
  if metadata.get("drill_id") != spec.drill_id:
    raise PublishError("metadata drill_id does not match the manifest")
  if metadata.get("title") != spec.title or metadata.get("artist") != spec.artist:
    raise PublishError("metadata title/artist does not match the manifest")
  if metadata.get("rights_confirmed") is not True:
    raise PublishError("metadata does not confirm content rights")
  if metadata.get("publish_status") != "approved_for_publication":
    raise PublishError("asset is not approved for publication")
  if metadata.get("pitch_map_kind") != "reviewed_target_contour":
    raise PublishError("pitch map is not a reviewed target contour")

  if metadata.get("audio_sha256") != _sha256(instrumental_path):
    raise PublishError("instrumental hash does not match metadata")
  if metadata.get("pitch_map_sha256") != _sha256(pitch_map_path):
    raise PublishError("pitch map hash does not match metadata")
  _read_pitch_map(pitch_map_path)
  return PublishArtifacts(directory, instrumental_path, pitch_map_path, metadata_path, metadata)


def publish_song(
  spec: SongSpec,
  assets_root: Path,
  *,
  uploader: AssetUploader,
  writer: CatalogWriter,
  overwrite: bool = False,
) -> dict[str, str]:
  artifacts = load_publish_artifacts(spec, assets_root)
  base_public_id = f"{spec.drill_id}"
  audio_response = uploader.upload(
    artifacts.instrumental_path,
    resource_type="video",
    public_id=f"{base_public_id}/instrumental",
    format_name="mp3",
    overwrite=overwrite,
  )
  pitch_response = uploader.upload(
    artifacts.pitch_map_path,
    resource_type="raw",
    public_id=f"{base_public_id}/pitch_map",
    format_name="json",
    overwrite=overwrite,
  )

  instrumental_url = audio_response.get("secure_url")
  pitch_map_url = pitch_response.get("secure_url")
  if not isinstance(instrumental_url, str) or not isinstance(pitch_map_url, str):
    raise PublishError("Cloudinary returned an invalid asset URL")
  writer.update_urls(
    spec.drill_id,
    instrumental_url=instrumental_url,
    pitch_map_url=pitch_map_url,
    metadata=artifacts.metadata,
  )
  return {"drill_id": spec.drill_id, "instrumental_url": instrumental_url, "pitch_map_url": pitch_map_url}


def _parser() -> argparse.ArgumentParser:
  parser = argparse.ArgumentParser(description=__doc__)
  subparsers = parser.add_subparsers(dest="command", required=True)
  plan = subparsers.add_parser("plan", help="validate reviewed assets without external writes")
  plan.add_argument("--manifest", type=Path, required=True)
  plan.add_argument("--assets", type=Path, required=True)
  plan.add_argument("--drill-id", action="append")

  publish = subparsers.add_parser("publish", help="publish reviewed assets and update existing Firestore docs")
  publish.add_argument("--manifest", type=Path, required=True)
  publish.add_argument("--assets", type=Path, required=True)
  publish.add_argument("--drill-id", action="append")
  publish.add_argument("--overwrite", action="store_true", help="allow replacement of deterministic Cloudinary assets")
  publish.add_argument("--execute", action="store_true", help="confirm external Cloudinary and Firestore writes")
  return parser


def _selected_specs(specs: Sequence[SongSpec], drill_ids: list[str] | None) -> list[SongSpec]:
  if not drill_ids:
    return list(specs)
  selected = {value.strip() for value in drill_ids if value.strip()}
  unknown = selected - {spec.drill_id for spec in specs}
  if unknown:
    raise PublishError("unknown drill ID in selection")
  return [spec for spec in specs if spec.drill_id in selected]


def main(argv: Sequence[str] | None = None) -> int:
  args = _parser().parse_args(argv)
  try:
    specs = _selected_specs(load_manifest(args.manifest), args.drill_id)
    if args.command == "plan":
      blocked = 0
      for spec in specs:
        try:
          artifacts = load_publish_artifacts(spec, args.assets)
        except PublishError as exc:
          blocked += 1
          print(f"{spec.drill_id}: blocked ({exc})")
        else:
          print(f"{spec.drill_id}: ready; {artifacts.pitch_map_path.name} validated")
      return 1 if blocked else 0

    if not args.execute:
      print("publication not run; pass --execute to confirm external writes")
      return 2
    uploader = CloudinaryUploader.from_environment()
    writer = FirestoreCatalogWriter.from_application_default_credentials()
    for spec in specs:
      result = publish_song(spec, args.assets, uploader=uploader, writer=writer, overwrite=args.overwrite)
      print(f"{result['drill_id']}: published and linked")
    return 0
  except (PublishError, OSError) as exc:
    print(f"publication blocked: {exc}")
    return 2


if __name__ == "__main__":
  raise SystemExit(main())
