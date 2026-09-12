"""Safe, manifest-driven preparation of authorized karaoke assets.

This tool deliberately stops at local, reviewable output. It never writes to
Cloudinary, Firestore, or another production service. A pitch map produced here
is an observed vocal fundamental-frequency contour, not a verified melody or
musical-key transcription.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


class ManifestError(ValueError):
  """Raised when a content manifest is unsafe or incomplete."""


@dataclass(frozen=True)
class SongSpec:
  drill_id: str
  title: str
  artist: str
  catalog_code: str | None
  catalog_volume: str | None
  source_url: str | None
  rights_confirmed: bool
  source_status: str
  analysis_min_hz: float
  analysis_max_hz: float


_DRILL_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{2,79}$")
_YOUTUBE_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}


def _required_text(value: object, field_name: str) -> str:
  if not isinstance(value, str) or not value.strip():
    raise ManifestError(f"{field_name} must be a non-empty string")
  return value.strip()


def _optional_text(value: object, field_name: str) -> str | None:
  if value is None or value == "":
    return None
  if not isinstance(value, str) or not value.strip():
    raise ManifestError(f"{field_name} must be a string or null")
  return value.strip()


def _finite_float(value: object, field_name: str) -> float:
  if isinstance(value, bool):
    raise ManifestError(f"{field_name} must be finite")
  try:
    number = float(value)
  except (TypeError, ValueError) as exc:
    raise ManifestError(f"{field_name} must be finite") from exc
  if not math.isfinite(number):
    raise ManifestError(f"{field_name} must be finite")
  return number


def _validate_youtube_url(value: str) -> str:
  parsed = urlparse(value)
  if parsed.scheme != "https" or parsed.hostname not in _YOUTUBE_HOSTS:
    raise ManifestError(f"source_url must be an HTTPS YouTube URL: {value}")
  if parsed.hostname == "youtu.be" and not parsed.path.strip("/"):
    raise ManifestError("source_url must include a YouTube video ID")
  if parsed.hostname != "youtu.be":
    if parsed.path != "/watch":
      raise ManifestError("source_url must be a YouTube watch URL")
    video_ids = parse_qs(parsed.query).get("v", [])
    if not video_ids or not video_ids[0].strip():
      raise ManifestError("source_url must include a YouTube video ID")
  return value


def load_manifest_data(manifest: Mapping[str, Any]) -> list[SongSpec]:
  """Validate a content manifest before any network or media operation."""
  if manifest.get("schema_version") != 1:
    raise ManifestError("schema_version must be 1")
  if manifest.get("rights_confirmed") is not True:
    raise ManifestError("manifest rights_confirmed must be true before processing")

  raw_songs = manifest.get("songs")
  if not isinstance(raw_songs, list) or not raw_songs:
    raise ManifestError("songs must be a non-empty list")

  specs: list[SongSpec] = []
  seen_ids: set[str] = set()
  for index, raw_song in enumerate(raw_songs):
    if not isinstance(raw_song, Mapping):
      raise ManifestError(f"songs[{index}] must be an object")

    drill_id = _required_text(raw_song.get("drill_id"), f"songs[{index}].drill_id")
    if not _DRILL_ID_RE.fullmatch(drill_id):
      raise ManifestError(f"songs[{index}].drill_id has an unsafe format")
    if drill_id in seen_ids:
      raise ManifestError(f"duplicate drill_id: {drill_id}")
    seen_ids.add(drill_id)

    title = _required_text(raw_song.get("title"), f"songs[{index}].title")
    artist = _required_text(raw_song.get("artist"), f"songs[{index}].artist")
    catalog_code = _optional_text(raw_song.get("catalog_code"), f"songs[{index}].catalog_code")
    catalog_volume = _optional_text(raw_song.get("catalog_volume"), f"songs[{index}].catalog_volume")

    per_song_rights = raw_song.get("rights_confirmed", True)
    if per_song_rights is not True:
      raise ManifestError(f"songs[{index}].rights_confirmed must be true")

    source_url = _optional_text(raw_song.get("source_url"), f"songs[{index}].source_url")
    if source_url is not None:
      source_url = _validate_youtube_url(source_url)

    source_status = raw_song.get("source_status")
    if source_status is None:
      source_status = "candidate" if source_url else "needs_source"
    source_status = _required_text(source_status, f"songs[{index}].source_status")

    analysis_min_hz = _finite_float(
      raw_song.get("analysis_min_hz", 65.0),
      f"songs[{index}].analysis_min_hz",
    )
    analysis_max_hz = _finite_float(
      raw_song.get("analysis_max_hz", 1046.5),
      f"songs[{index}].analysis_max_hz",
    )
    if analysis_min_hz <= 0 or analysis_max_hz <= analysis_min_hz:
      raise ManifestError(f"songs[{index}] analysis frequency range is invalid")

    specs.append(
      SongSpec(
        drill_id=drill_id,
        title=title,
        artist=artist,
        catalog_code=catalog_code,
        catalog_volume=catalog_volume,
        source_url=source_url,
        rights_confirmed=True,
        source_status=source_status,
        analysis_min_hz=analysis_min_hz,
        analysis_max_hz=analysis_max_hz,
      )
    )
  return specs


def load_manifest(path: Path) -> list[SongSpec]:
  try:
    payload = json.loads(path.read_text(encoding="utf-8"))
  except (OSError, json.JSONDecodeError) as exc:
    raise ManifestError(f"could not read manifest {path}") from exc
  if not isinstance(payload, Mapping):
    raise ManifestError("manifest root must be an object")
  return load_manifest_data(payload)


def _finite_or_none(value: object) -> float | None:
  if isinstance(value, bool):
    return None
  try:
    number = float(value)
  except (TypeError, ValueError):
    return None
  return number if math.isfinite(number) else None


def sanitize_pitch_points(
  raw_points: Iterable[Mapping[str, Any]],
  *,
  min_frequency_hz: float,
  max_frequency_hz: float,
  min_confidence: float = 0.75,
) -> list[dict[str, float]]:
  """Keep only finite, bounded, sufficiently confident F0 observations."""
  if min_frequency_hz <= 0 or max_frequency_hz <= min_frequency_hz:
    raise ValueError("invalid frequency range")
  if not 0 <= min_confidence <= 1:
    raise ValueError("min_confidence must be between 0 and 1")

  by_time: dict[float, dict[str, float]] = {}
  for raw_point in raw_points:
    time_sec = _finite_or_none(raw_point.get("time"))
    frequency_hz = _finite_or_none(raw_point.get("pitch"))
    confidence = _finite_or_none(raw_point.get("confidence", 1.0))
    if time_sec is None or frequency_hz is None or confidence is None:
      continue
    if time_sec < 0 or not min_frequency_hz <= frequency_hz <= max_frequency_hz:
      continue
    if not 0 <= confidence <= 1 or confidence < min_confidence:
      continue

    point = {
      "time": round(time_sec, 3),
      "pitch": round(frequency_hz, 2),
      "confidence": round(confidence, 4),
    }
    previous = by_time.get(point["time"])
    if previous is None or point["confidence"] > previous["confidence"]:
      by_time[point["time"]] = point

  return [by_time[key] for key in sorted(by_time)]


def summarize_pitch_points(points: Sequence[Mapping[str, float]], *, audio_duration_sec: float) -> dict[str, Any]:
  """Return bounded evidence metadata for an observed vocal contour."""
  duration = max(0.0, float(audio_duration_sec)) if math.isfinite(audio_duration_sec) else 0.0
  if not points:
    return {
      "point_count": 0,
      "audio_duration_sec": round(duration, 3),
      "coverage_ratio": 0.0,
      "min_pitch_hz": None,
      "max_pitch_hz": None,
      "pitch_map_kind": "observed_vocal_contour",
    }

  times = [float(point["time"]) for point in points]
  pitches = [float(point["pitch"]) for point in points]
  observed_span = max(0.0, max(times) - min(times))
  coverage_ratio = min(1.0, observed_span / duration) if duration > 0 else 0.0
  return {
    "point_count": len(points),
    "audio_duration_sec": round(duration, 3),
    "coverage_ratio": round(coverage_ratio, 4),
    "min_pitch_hz": round(min(pitches), 2),
    "max_pitch_hz": round(max(pitches), 2),
    "pitch_map_kind": "observed_vocal_contour",
  }


def generate_pitch_map(
  vocal_path: Path,
  output_path: Path,
  *,
  min_frequency_hz: float,
  max_frequency_hz: float,
  min_confidence: float = 0.75,
) -> dict[str, Any]:
  """Run pYIN and save the legacy-compatible list format plus evidence stats."""
  try:
    import librosa
    import numpy as np
  except ImportError as exc:  # pragma: no cover - depends on local media toolchain
    raise RuntimeError("pYIN requires librosa and numpy in the local media environment") from exc

  audio, sample_rate = librosa.load(vocal_path, sr=None, mono=True)
  frame_length = 2048
  hop_length = 512
  f0, voiced_flag, voiced_probs = librosa.pyin(
    audio,
    fmin=min_frequency_hz,
    fmax=max_frequency_hz,
    sr=sample_rate,
    frame_length=frame_length,
    hop_length=hop_length,
  )
  times = librosa.frames_to_time(np.arange(len(f0)), sr=sample_rate, hop_length=hop_length)
  raw_points = (
    {
      "time": float(time_sec),
      "pitch": float(frequency),
      "confidence": float(probability),
    }
    for time_sec, frequency, is_voiced, probability in zip(times, f0, voiced_flag, voiced_probs)
    if bool(is_voiced)
  )
  points = sanitize_pitch_points(
    raw_points,
    min_frequency_hz=min_frequency_hz,
    max_frequency_hz=max_frequency_hz,
    min_confidence=min_confidence,
  )
  output_path.parent.mkdir(parents=True, exist_ok=True)
  output_path.write_text(
    json.dumps([{"time": point["time"], "pitch": point["pitch"]} for point in points], indent=2) + "\n",
    encoding="utf-8",
  )
  return summarize_pitch_points(points, audio_duration_sec=len(audio) / sample_rate)


def _sha256(path: Path) -> str:
  digest = hashlib.sha256()
  with path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
      digest.update(chunk)
  return digest.hexdigest()


def _run(command: Sequence[str]) -> None:
  subprocess.run(list(command), check=True)


def _find_asset(directory: Path, filename: str) -> Path:
  matches = list(directory.rglob(filename))
  if len(matches) != 1:
    raise RuntimeError(f"expected exactly one {filename} under {directory}, found {len(matches)}")
  return matches[0]


def _ensure_reusable_directory(path: Path) -> None:
  """Create an empty staging directory without overwriting partial work."""
  if path.exists():
    if not path.is_dir() or any(path.iterdir()):
      raise FileExistsError(f"work directory already contains files: {path}")
    return
  path.mkdir(parents=True, exist_ok=False)


def process_song(
  spec: SongSpec,
  output_root: Path,
  *,
  ytdlp_bin: str = "yt-dlp",
  demucs_bin: str = "demucs",
  ffmpeg_bin: str = "ffmpeg",
) -> dict[str, Any]:
  """Prepare one authorized source without publishing it anywhere."""
  if not spec.rights_confirmed:
    raise ManifestError(f"rights are not confirmed for {spec.drill_id}")
  if not spec.source_url:
    raise ManifestError(f"no source_url is available for {spec.drill_id}")

  work_dir = output_root / ".work" / spec.drill_id
  final_dir = output_root / spec.drill_id
  _ensure_reusable_directory(work_dir)
  _ensure_reusable_directory(final_dir)

  raw_audio = work_dir / "source.wav"
  separated_dir = work_dir / "separated"
  _run(
    [
      ytdlp_bin,
      "--no-playlist",
      "--extract-audio",
      "--audio-format",
      "wav",
      "--audio-quality",
      "0",
      "--output",
      str(work_dir / "source.%(ext)s"),
      spec.source_url,
    ]
  )
  if not raw_audio.exists():
    raise RuntimeError(f"yt-dlp did not produce {raw_audio}")

  _run(
    [
      demucs_bin,
      "--two-stems",
      "vocals",
      "-n",
      "htdemucs",
      "-o",
      str(separated_dir),
      str(raw_audio),
    ]
  )
  vocals_path = _find_asset(separated_dir, "vocals.wav")
  instrumental_path = _find_asset(separated_dir, "no_vocals.wav")

  final_dir.mkdir(parents=True, exist_ok=True)
  pitch_map_path = final_dir / "pitch_map.json"
  pitch_summary = generate_pitch_map(
    vocals_path,
    pitch_map_path,
    min_frequency_hz=spec.analysis_min_hz,
    max_frequency_hz=spec.analysis_max_hz,
  )
  instrumental_output = final_dir / "instrumental.mp3"
  _run(
    [
      ffmpeg_bin,
      "-y",
      "-i",
      str(instrumental_path),
      "-codec:a",
      "libmp3lame",
      "-b:a",
      "128k",
      str(instrumental_output),
    ]
  )

  metadata = {
    "schema_version": 1,
    "drill_id": spec.drill_id,
    "title": spec.title,
    "artist": spec.artist,
    "catalog_code": spec.catalog_code,
    "catalog_volume": spec.catalog_volume,
    "source_url": spec.source_url,
    "rights_confirmed": spec.rights_confirmed,
    "pitch_map_kind": "observed_vocal_contour",
    "pitch_analysis": pitch_summary,
    "analysis_range_hz": {
      "min": spec.analysis_min_hz,
      "max": spec.analysis_max_hz,
      "confidence_floor": 0.75,
    },
    "audio_sha256": _sha256(instrumental_output),
    "pitch_map_sha256": _sha256(pitch_map_path),
    "publish_status": "local_review_required",
  }
  (final_dir / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
  return metadata


def _build_parser() -> argparse.ArgumentParser:
  parser = argparse.ArgumentParser(description=__doc__)
  subparsers = parser.add_subparsers(dest="command", required=True)

  validate = subparsers.add_parser("validate", help="validate a manifest without network access")
  validate.add_argument("--manifest", type=Path, required=True)

  process = subparsers.add_parser("process", help="prepare authorized assets locally")
  process.add_argument("--manifest", type=Path, required=True)
  process.add_argument("--output", type=Path, required=True)
  process.add_argument(
    "--execute-download",
    action="store_true",
    help="perform the authorized YouTube download; omitted means plan-only",
  )
  process.add_argument("--ytdlp-bin", default="yt-dlp")
  process.add_argument("--demucs-bin", default="demucs")
  process.add_argument("--ffmpeg-bin", default="ffmpeg")
  return parser


def main(argv: Sequence[str] | None = None) -> int:
  args = _build_parser().parse_args(argv)
  try:
    specs = load_manifest(args.manifest)
  except ManifestError as exc:
    print(f"manifest invalid: {exc}")
    return 2

  if args.command == "validate":
    with_source = sum(spec.source_url is not None for spec in specs)
    print(f"validated {len(specs)} entries; {with_source} have source URLs")
    return 0

  if not args.execute_download:
    for spec in specs:
      state = "ready to process" if spec.source_url else "needs source URL"
      print(f"{spec.drill_id}: {state}")
    print("plan only; pass --execute-download to run local media processing")
    return 0

  failures = 0
  for spec in specs:
    if not spec.source_url:
      print(f"{spec.drill_id}: skipped (no source URL)")
      continue
    try:
      result = process_song(
        spec,
        args.output,
        ytdlp_bin=args.ytdlp_bin,
        demucs_bin=args.demucs_bin,
        ffmpeg_bin=args.ffmpeg_bin,
      )
      print(
        f"{spec.drill_id}: local assets ready for review; "
        f"{result['pitch_analysis']['point_count']} pitch points"
      )
    except Exception as exc:  # noqa: BLE001  # keep processing independent manifest entries
      failures += 1
      print(f"{spec.drill_id}: failed ({type(exc).__name__})")
  return 1 if failures else 0


if __name__ == "__main__":
  raise SystemExit(main())
