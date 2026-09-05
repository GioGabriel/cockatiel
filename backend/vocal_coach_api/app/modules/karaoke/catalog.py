import logging
from copy import deepcopy
from typing import Any

from app.core.config import settings
from app.repositories.firestore.client import build_firestore_client

logger = logging.getLogger("vocal-coach-api.karaoke.catalog")


def _is_production_environment() -> bool:
  return settings.app_env.strip().lower() in {"prod", "production", "staging"}


def _local_drill(
  drill_id: str,
  *,
  title: str,
  style_category: str,
  difficulty: str,
  duration_sec: int,
  tempo_bpm: int,
  low: str,
  high: str,
  objective: str,
) -> dict[str, Any]:
  return _apply_drill_defaults(
    drill_id,
    {
      "title": title,
      "style_category": style_category,
      "difficulty": difficulty,
      "duration_sec": duration_sec,
      "tempo_bpm": tempo_bpm,
      "vocal_range": {"low": low, "high": high},
      "objective": objective,
      "artist_name": "Cockatiel Practice Library",
      "performance_tips": [
        "Listen for the target pitch before you sing.",
        "Keep the jaw relaxed and follow the live cue.",
      ],
      "melody_reference": [
        {"note": "C4", "start_beat": 0.0, "duration_beats": 4.0},
        {"note": "E4", "start_beat": 4.0, "duration_beats": 4.0},
        {"note": "G4", "start_beat": 8.0, "duration_beats": 4.0},
      ],
    },
  )


def _local_fallback_catalog() -> dict[str, Any]:
  """Return metadata-only drills for local/demo resilience.

  These entries intentionally contain no audio, lyrics, cover art, or pitch-map
  URLs. External content must be configured and authorized separately.
  """
  drills = [
    _local_drill(
      "pop_breath_control_1",
      title="Open Sky Warmup",
      style_category="Pop Practice",
      difficulty="beginner",
      duration_sec=120,
      tempo_bpm=96,
      low="C3",
      high="C5",
      objective="Practice steady breath and clear pitch on a simple pop phrase.",
    ),
    _local_drill(
      "acoustic_pitch_ladder_1",
      title="Acoustic Pitch Ladder",
      style_category="Acoustic Practice",
      difficulty="intermediate",
      duration_sec=150,
      tempo_bpm=104,
      low="D3",
      high="D5",
      objective="Connect stepwise notes while keeping the tone relaxed.",
    ),
    _local_drill(
      "classic_phrase_control_1",
      title="Classic Phrase Control",
      style_category="Classic Practice",
      difficulty="advanced",
      duration_sec=180,
      tempo_bpm=72,
      low="A2",
      high="E5",
      objective="Build phrase control, timing, and expressive note transitions.",
    ),
  ]
  category_map: dict[str, dict[str, Any]] = {}
  for drill in drills:
    style_label = str(drill["style_category"])
    category_id = style_label.lower().replace(" ", "_")
    category_map.setdefault(
      category_id,
      {
        "category_id": category_id,
        "style_label": style_label,
        "description": f"{style_label} drills for guided singing practice.",
        "drills": [],
      },
    )["drills"].append(drill)
  return {
    "module_id": "karaoke",
    "title": "Karaoke Practice",
    "description": "Song-based vocal drills with local live pitch guidance.",
    "categories": list(category_map.values()),
  }


def _apply_drill_defaults(drill_id: str, raw_data: dict[str, Any]) -> dict[str, Any]:
  """Apply safe defaults so clients can render partially configured drills."""
  drill = {
    "drill_id": drill_id,
    "title": raw_data.get("title") or drill_id,
    "style_category": raw_data.get("style_category") or "Pop Ballad",
    "difficulty": raw_data.get("difficulty") or "intermediate",
    "duration_sec": int(raw_data.get("duration_sec") or 240),
    "tempo_bpm": int(raw_data.get("tempo_bpm") or 120),
    "objective": raw_data.get("objective") or "Sing along and match the pitch!",
    "artist_name": raw_data.get("artist_name") or "Unknown Artist",
    "instrumental_url": raw_data.get("instrumental_url") or "",
    "pitch_map_url": raw_data.get("pitch_map_url") or "",
    "cover_url": raw_data.get("cover_url") or "",
  }

  vocal_range = raw_data.get("vocal_range") or {}
  drill["vocal_range"] = {
    "low": vocal_range.get("low") or "C3",
    "high": vocal_range.get("high") or "C5",
  }

  performance_tips = raw_data.get("performance_tips") or []
  drill["performance_tips"] = performance_tips or [
    "Maintain pitch accuracy and expressive dynamics",
  ]

  melody_reference = raw_data.get("melody_reference") or []
  drill["melody_reference"] = melody_reference or [
    {"note": "C4", "start_beat": 0.0, "duration_beats": 4.0},
  ]

  return drill


def get_catalog() -> dict[str, Any]:
  """Fetch all karaoke drills from Firestore and group them by category."""
  base_catalog = {
    "module_id": "karaoke",
    "title": "Karaoke Practice",
    "description": "Song-based vocal drills with local live pitch guidance and coaching review.",
    "categories": [],
  }

  if not settings.firestore_enabled:
    if _is_production_environment():
      logger.error("Karaoke catalog is not configured: Firestore is disabled in production.")
      return base_catalog
    logger.info("Firestore is disabled. Returning metadata-only local karaoke catalog.")
    return _local_fallback_catalog()

  try:
    db = build_firestore_client()
    docs = db.collection("karaoke_songs").stream()
    categories_map: dict[str, dict[str, Any]] = {}

    for doc in docs:
      raw_data = doc.to_dict() or {}
      drill = _apply_drill_defaults(doc.id, raw_data)
      style_label = str(drill["style_category"])
      category_id = style_label.lower().replace(" ", "_")
      categories_map.setdefault(
        category_id,
        {
          "category_id": category_id,
          "style_label": style_label,
          "description": f"{style_label} songs emphasizing vocal control.",
          "drills": [],
        },
      )["drills"].append(drill)

    base_catalog["categories"] = list(categories_map.values())
    if base_catalog["categories"] or _is_production_environment():
      if not base_catalog["categories"]:
        logger.warning("Karaoke catalog is empty in production.")
      return base_catalog
    return _local_fallback_catalog()
  except Exception as exc:
    logger.warning("Failed to fetch karaoke catalog from Firestore: %s", type(exc).__name__)
    if _is_production_environment():
      raise RuntimeError("Karaoke catalog unavailable in production.") from exc
    return _local_fallback_catalog()


def get_drill_by_id(drill_id: str) -> dict[str, Any] | None:
  """Fetch a single drill from Firestore by its ID."""
  if not settings.firestore_enabled:
    if _is_production_environment():
      logger.error("Karaoke drill lookup is unavailable: Firestore is disabled in production.")
      return None
    for category in _local_fallback_catalog()["categories"]:
      for drill in category["drills"]:
        if drill["drill_id"] == drill_id:
          return deepcopy(drill)
    return None

  try:
    db = build_firestore_client()
    doc = db.collection("karaoke_songs").document(drill_id).get()
    if doc.exists:
      return _apply_drill_defaults(doc.id, doc.to_dict() or {})
  except Exception as exc:
    logger.warning("Failed to fetch karaoke drill %s from Firestore: %s", drill_id, type(exc).__name__)
    if _is_production_environment():
      raise RuntimeError("Karaoke catalog unavailable in production.") from exc

  if _is_production_environment():
    return None

  for category in _local_fallback_catalog()["categories"]:
    for drill in category["drills"]:
      if drill["drill_id"] == drill_id:
        return deepcopy(drill)
  return None
