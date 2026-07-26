from typing import Any
import logging

from app.core.config import settings
from app.repositories.firestore.client import build_firestore_client

logger = logging.getLogger("vocal-coach-api.karaoke.catalog")

def _apply_drill_defaults(drill_id: str, raw_data: dict[str, Any]) -> dict[str, Any]:
    """Applies sensible defaults to a drill to ensure the Flutter frontend can parse it safely."""
    # Base required fields
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
    }
    
    # Complex fields
    vocal_range = raw_data.get("vocal_range") or {}
    drill["vocal_range"] = {
        "low": vocal_range.get("low") or "C3",
        "high": vocal_range.get("high") or "C5"
    }
    
    performance_tips = raw_data.get("performance_tips") or []
    if not performance_tips:
        performance_tips = ["Maintain pitch accuracy and expressive dynamics"]
    drill["performance_tips"] = performance_tips
    
    melody_reference = raw_data.get("melody_reference") or []
    if not melody_reference:
        melody_reference = [
            {"note": "C4", "start_beat": 0.0, "duration_beats": 4.0}
        ]
    drill["melody_reference"] = melody_reference
    
    return drill


def get_catalog() -> dict[str, Any]:
    """Dynamically fetch all karaoke drills from Firestore and group them by category."""
    base_catalog = {
        "module_id": "karaoke",
        "title": "Karaoke Practice",
        "description": "Song-based vocal drills combining entertainment with AI evaluation.",
        "categories": []
    }
    
    if not settings.firestore_enabled:
        logger.warning("Firestore is disabled. Returning empty karaoke catalog.")
        return base_catalog

    try:
        db = build_firestore_client()
        docs = db.collection("karaoke_songs").stream()
        
        categories_map: dict[str, dict[str, Any]] = {}
        
        for doc in docs:
            raw_data = doc.to_dict() or {}
            drill_id = doc.id
            drill = _apply_drill_defaults(drill_id, raw_data)
            
            style_label = drill["style_category"]
            category_id = style_label.lower().replace(" ", "_")
            
            if category_id not in categories_map:
                categories_map[category_id] = {
                    "category_id": category_id,
                    "style_label": style_label,
                    "description": f"{style_label} songs emphasizing vocal control.",
                    "drills": []
                }
            
            categories_map[category_id]["drills"].append(drill)
            
        base_catalog["categories"] = list(categories_map.values())
        return base_catalog

    except Exception as exc:
        logger.error(f"Failed to fetch karaoke catalog from Firestore: {exc}")
        return base_catalog


def get_drill_by_id(drill_id: str) -> dict[str, Any] | None:
    """Fetch a single drill from Firestore by its ID."""
    if not settings.firestore_enabled:
        return None
        
    try:
        db = build_firestore_client()
        doc_ref = db.collection("karaoke_songs").document(drill_id)
        doc = doc_ref.get()
        
        if not doc.exists:
            return None
            
        raw_data = doc.to_dict() or {}
        return _apply_drill_defaults(doc.id, raw_data)
        
    except Exception as exc:
        logger.error(f"Failed to fetch karaoke drill {drill_id} from Firestore: {exc}")
        return None
