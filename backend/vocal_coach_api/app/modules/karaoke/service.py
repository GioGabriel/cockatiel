from typing import Any

from app.modules.karaoke.catalog import get_catalog, get_drill_by_id as _get_drill_by_id


def get_karaoke_catalog() -> dict[str, Any]:
  """Return the full karaoke drill catalog."""
  return get_catalog()


def get_drill_by_id(drill_id: str) -> dict[str, Any] | None:
  """Return a single drill by ID, or None if not found."""
  return _get_drill_by_id(drill_id)


def get_catalog_preview() -> dict[str, Any]:
  """Return a lightweight preview of the catalog without full drill details."""
  catalog = get_catalog()
  categories_preview = []
  total_drills = 0
  for cat in catalog["categories"]:
    drill_count = len(cat["drills"])
    total_drills += drill_count
    categories_preview.append({
      "category_id": cat["category_id"],
      "style_label": cat["style_label"],
      "drill_count": drill_count,
    })
  return {
    "module_id": catalog["module_id"],
    "title": catalog["title"],
    "description": catalog["description"],
    "category_count": len(catalog["categories"]),
    "total_drills": total_drills,
    "categories": categories_preview,
  }
