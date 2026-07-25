from datetime import datetime, timedelta, timezone
from time import time
from typing import Any

from app.modules.training.scoring import BREATHING_METRIC_FIELDS, VOICE_METRIC_FIELDS
from app.repositories.provider import get_analytics_repository, get_session_repository

_RANGE_DAYS = (7, 30, 90)
_RANGE_DAY_MAP = {
  "7d": 7,
  "30d": 30,
  "90d": 90,
}

_LEGACY_AVG_TO_METRIC = {
  "avg_pitch_accuracy": "pitch_accuracy",
  "avg_timing_accuracy": "timing_accuracy",
  "avg_breath_control": "breath_control",
}

_METRIC_LABELS = {
  "pitch_accuracy": "Pitch accuracy",
  "timing_accuracy": "Timing accuracy",
  "breath_control": "Breath control",
  "pitch_stability": "Pitch stability",
  "vibrato_consistency": "Vibrato consistency",
  "note_transition_smoothness": "Transition smoothness",
  "phase_completion_rate": "Phase completion",
  "pace_adherence": "Pace adherence",
  "cycle_consistency": "Cycle consistency",
  "completion_rate": "Completion rate",
}

_DEFAULT_PRIMARY_METRICS = {
  "voice": ("pitch_accuracy", "timing_accuracy", "breath_control"),
  "breathing": ("phase_completion_rate", "pace_adherence", "cycle_consistency"),
}

_MODE_METRIC_ORDER = {
  "voice": (
    "pitch_accuracy",
    "timing_accuracy",
    "breath_control",
    "pitch_stability",
    "note_transition_smoothness",
    "vibrato_consistency",
  ),
  "breathing": (
    "phase_completion_rate",
    "pace_adherence",
    "cycle_consistency",
    "completion_rate",
  ),
}


def _session_timestamp_ms(session: dict[str, Any]) -> int:
  return int(session.get("completed_at") or session.get("created_at") or 0)


def _safe_float(value: Any) -> float:
  try:
    return float(value)
  except (TypeError, ValueError):
    return 0.0


def _safe_int(value: Any) -> int:
  try:
    return int(value)
  except (TypeError, ValueError):
    return 0


def _completed_sessions(user_id: str) -> list[dict[str, Any]]:
  repository = get_session_repository()
  sessions = repository.list_by_user(user_id)
  return [item for item in sessions if item.get("status") == "completed"]


def _metric_mode_from_summary(metrics_summary: dict[str, Any]) -> str:
  normalized = str(metrics_summary.get("metric_mode") or "").strip().lower()
  if normalized in {"voice", "breathing"}:
    return normalized
  if any(field in metrics_summary for field in BREATHING_METRIC_FIELDS):
    return "breathing"
  return "voice"


def _metric_fields_for_mode(metric_mode: str) -> tuple[str, ...]:
  return BREATHING_METRIC_FIELDS if metric_mode == "breathing" else VOICE_METRIC_FIELDS


def _available_metric_values(
  metrics_summary: dict[str, Any],
  metric_mode: str,
) -> dict[str, float]:
  values: dict[str, float] = {}
  for field in _metric_fields_for_mode(metric_mode):
    if field in metrics_summary:
      values[field] = round(_safe_float(metrics_summary.get(field)), 2)
  return values


def _exercise_focus_metrics(session: dict[str, Any]) -> list[str]:
  exercise_spec = session.get("exercise_spec") or {}
  raw = exercise_spec.get("focus_metrics") if isinstance(exercise_spec, dict) else None
  if not isinstance(raw, list):
    return []
  return [str(item).strip().lower() for item in raw if str(item).strip()]


def _primary_metric_keys_for_session(
  session: dict[str, Any],
  metric_values: dict[str, float],
  metric_mode: str,
) -> list[str]:
  available_keys = list(metric_values.keys())
  if not available_keys:
    return []

  primary_keys = [
    field for field in _exercise_focus_metrics(session) if field in metric_values
  ]

  for field in _DEFAULT_PRIMARY_METRICS[metric_mode]:
    if field in metric_values and field not in primary_keys:
      primary_keys.append(field)

  for field in _MODE_METRIC_ORDER[metric_mode]:
    if field in metric_values and field not in primary_keys:
      primary_keys.append(field)

  return primary_keys[:3]


def _empty_range() -> dict[str, Any]:
  return {
    "session_count": 0,
    "avg_score": 0.0,
    "avg_pitch_accuracy": 0.0,
    "avg_timing_accuracy": 0.0,
    "avg_breath_control": 0.0,
    "primary_metric_mode": None,
    "primary_metrics": [],
  }


def _metric_average(
  metric_key: str,
  metric_totals: dict[str, float],
  metric_counts: dict[str, int],
) -> float:
  count = _safe_int(metric_counts.get(metric_key))
  if count <= 0:
    return 0.0
  return round(_safe_float(metric_totals.get(metric_key)) / count, 2)


def _legacy_averages_from_metrics(
  metric_totals: dict[str, float],
  metric_counts: dict[str, int],
) -> dict[str, float]:
  return {
    field: _metric_average(metric_key, metric_totals, metric_counts)
    for field, metric_key in _LEGACY_AVG_TO_METRIC.items()
  }


def _merge_float_maps(
  left: dict[str, float],
  right: dict[str, float],
) -> dict[str, float]:
  keys = set(left.keys()) | set(right.keys())
  return {
    key: round(_safe_float(left.get(key)) + _safe_float(right.get(key)), 2)
    for key in keys
  }


def _merge_int_maps(
  left: dict[str, int],
  right: dict[str, int],
) -> dict[str, int]:
  keys = set(left.keys()) | set(right.keys())
  return {
    key: _safe_int(left.get(key)) + _safe_int(right.get(key))
    for key in keys
  }


def _dominant_metric_mode(mode_counts: dict[str, int]) -> str | None:
  voice_count = _safe_int(mode_counts.get("voice"))
  breathing_count = _safe_int(mode_counts.get("breathing"))
  if voice_count <= 0 and breathing_count <= 0:
    return None
  return "breathing" if breathing_count > voice_count else "voice"


def _ordered_metric_keys(dominant_mode: str | None) -> list[str]:
  primary_mode = dominant_mode or "voice"
  secondary_mode = "breathing" if primary_mode == "voice" else "voice"
  ordered = list(_MODE_METRIC_ORDER[primary_mode]) + list(_MODE_METRIC_ORDER[secondary_mode])
  seen: set[str] = set()
  deduped: list[str] = []
  for key in ordered:
    if key in seen:
      continue
    seen.add(key)
    deduped.append(key)
  return deduped


def _build_primary_metrics(
  metric_totals: dict[str, float],
  metric_counts: dict[str, int],
  primary_metric_votes: dict[str, int],
  mode_counts: dict[str, int],
) -> list[dict[str, Any]]:
  dominant_mode = _dominant_metric_mode(mode_counts)
  ordered_keys = _ordered_metric_keys(dominant_mode)
  priority = {key: index for index, key in enumerate(ordered_keys)}

  candidate_keys = [
    key for key in ordered_keys if _safe_int(metric_counts.get(key)) > 0
  ]
  candidate_keys.sort(
    key=lambda key: (
      -_safe_int(primary_metric_votes.get(key)),
      -_safe_int(metric_counts.get(key)),
      priority.get(key, 999),
    ),
  )

  return [
    {
      "metric_key": key,
      "label": _METRIC_LABELS.get(key, key.replace("_", " ").title()),
      "avg_value": _metric_average(key, metric_totals, metric_counts),
      "session_count": _safe_int(metric_counts.get(key)),
    }
    for key in candidate_keys[:3]
  ]


def _metrics_state_from_rollup(
  rollup: dict[str, Any],
) -> tuple[dict[str, float], dict[str, int], dict[str, int], dict[str, int]]:
  raw_totals = rollup.get("metric_totals") or {}
  raw_counts = rollup.get("metric_counts") or {}
  raw_votes = rollup.get("primary_metric_votes") or {}
  raw_mode_counts = rollup.get("mode_counts") or {}

  metric_totals = {
    str(key): round(_safe_float(value), 2)
    for key, value in dict(raw_totals).items()
  }
  metric_counts = {
    str(key): _safe_int(value)
    for key, value in dict(raw_counts).items()
  }
  primary_metric_votes = {
    str(key): _safe_int(value)
    for key, value in dict(raw_votes).items()
  }
  mode_counts = {
    str(key): _safe_int(value)
    for key, value in dict(raw_mode_counts).items()
  }

  if not metric_totals and not metric_counts:
    session_count = max(_safe_int(rollup.get("session_count")), 0)
    for legacy_field, metric_key in _LEGACY_AVG_TO_METRIC.items():
      average = _safe_float(rollup.get(legacy_field))
      if average <= 0 or session_count <= 0:
        continue
      metric_totals[metric_key] = round(average * session_count, 2)
      metric_counts[metric_key] = session_count

  if not mode_counts:
    inferred_mode = str(rollup.get("primary_metric_mode") or "").strip().lower()
    if inferred_mode not in {"voice", "breathing"}:
      inferred_mode = (
        "breathing"
        if any(_safe_int(metric_counts.get(key)) > 0 for key in BREATHING_METRIC_FIELDS)
        else "voice"
      )
    session_count = max(_safe_int(rollup.get("session_count")), 0)
    if session_count > 0:
      mode_counts[inferred_mode] = session_count

  if not primary_metric_votes:
    inferred_mode = _dominant_metric_mode(mode_counts) or "voice"
    for key in _DEFAULT_PRIMARY_METRICS[inferred_mode]:
      if _safe_int(metric_counts.get(key)) > 0:
        primary_metric_votes[key] = _safe_int(metric_counts.get(key))

  return metric_totals, metric_counts, primary_metric_votes, mode_counts


def _rollup_from_session(session: dict[str, Any]) -> dict[str, Any] | None:
  timestamp_ms = _session_timestamp_ms(session)
  if timestamp_ms <= 0:
    return None

  metrics_summary = dict(session.get("metrics_summary") or {})
  metric_mode = _metric_mode_from_summary(metrics_summary)
  metric_values = _available_metric_values(metrics_summary, metric_mode)
  primary_metric_keys = _primary_metric_keys_for_session(
    session,
    metric_values,
    metric_mode,
  )
  date_key = datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc).date().isoformat()

  metric_totals = {
    key: round(value, 2)
    for key, value in metric_values.items()
  }
  metric_counts = {key: 1 for key in metric_values}
  primary_metric_votes = {key: 1 for key in primary_metric_keys}
  mode_counts = {metric_mode: 1}

  rollup = {
    "date": date_key,
    "session_count": 1,
    "avg_score": round(_safe_float(session.get("overall_score")), 2),
    "last_session_at": timestamp_ms,
    "updated_at": int(time() * 1000),
    "metric_totals": metric_totals,
    "metric_counts": metric_counts,
    "primary_metric_votes": primary_metric_votes,
    "mode_counts": mode_counts,
    "primary_metric_mode": metric_mode,
    "primary_metrics": _build_primary_metrics(
      metric_totals,
      metric_counts,
      primary_metric_votes,
      mode_counts,
    ),
  }
  rollup.update(_legacy_averages_from_metrics(metric_totals, metric_counts))
  return rollup


def _merge_rollups(existing: dict[str, Any] | None, incoming: dict[str, Any]) -> dict[str, Any]:
  if not existing:
    return dict(incoming)

  existing_count = _safe_int(existing.get("session_count"))
  incoming_count = _safe_int(incoming.get("session_count"))
  total_count = existing_count + incoming_count
  if total_count <= 0:
    return dict(incoming)

  existing_totals, existing_metric_counts, existing_votes, existing_mode_counts = (
    _metrics_state_from_rollup(existing)
  )
  incoming_totals, incoming_metric_counts, incoming_votes, incoming_mode_counts = (
    _metrics_state_from_rollup(incoming)
  )

  metric_totals = _merge_float_maps(existing_totals, incoming_totals)
  metric_counts = _merge_int_maps(existing_metric_counts, incoming_metric_counts)
  primary_metric_votes = _merge_int_maps(existing_votes, incoming_votes)
  mode_counts = _merge_int_maps(existing_mode_counts, incoming_mode_counts)

  merged = {
    "date": incoming.get("date") or existing.get("date"),
    "session_count": total_count,
    "avg_score": round(
      (
        (_safe_float(existing.get("avg_score")) * existing_count) +
        (_safe_float(incoming.get("avg_score")) * incoming_count)
      ) / total_count,
      2,
    ),
    "last_session_at": max(
      _safe_int(existing.get("last_session_at")),
      _safe_int(incoming.get("last_session_at")),
    ),
    "updated_at": int(time() * 1000),
    "metric_totals": metric_totals,
    "metric_counts": metric_counts,
    "primary_metric_votes": primary_metric_votes,
    "mode_counts": mode_counts,
    "primary_metric_mode": _dominant_metric_mode(mode_counts),
    "primary_metrics": _build_primary_metrics(
      metric_totals,
      metric_counts,
      primary_metric_votes,
      mode_counts,
    ),
  }
  merged.update(_legacy_averages_from_metrics(metric_totals, metric_counts))
  return merged


def _aggregate_sessions_to_rollups(sessions: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
  aggregated: dict[str, dict[str, Any]] = {}
  for session in sessions:
    rollup = _rollup_from_session(session)
    if not rollup:
      continue
    date_key = str(rollup["date"])
    aggregated[date_key] = _merge_rollups(aggregated.get(date_key), rollup)
  return aggregated


def _all_rollups(user_id: str) -> list[dict[str, Any]]:
  repository = get_analytics_repository()
  rollups = repository.list_daily_rollups(user_id)
  if rollups:
    return rollups

  sessions = _completed_sessions(user_id)
  if not sessions:
    return []

  aggregated = _aggregate_sessions_to_rollups(sessions)
  for date_key, rollup in aggregated.items():
    repository.upsert_daily_rollup(user_id, date_key, rollup)

  return repository.list_daily_rollups(user_id)


def _range_summary_from_rollups(rollups: list[dict[str, Any]]) -> dict[str, Any]:
  total_sessions = sum(_safe_int(item.get("session_count")) for item in rollups)
  if total_sessions <= 0:
    return _empty_range()

  total_score = 0.0
  metric_totals: dict[str, float] = {}
  metric_counts: dict[str, int] = {}
  primary_metric_votes: dict[str, int] = {}
  mode_counts: dict[str, int] = {}

  for item in rollups:
    session_count = _safe_int(item.get("session_count"))
    total_score += _safe_float(item.get("avg_score")) * session_count
    rollup_totals, rollup_counts, rollup_votes, rollup_mode_counts = (
      _metrics_state_from_rollup(item)
    )
    metric_totals = _merge_float_maps(metric_totals, rollup_totals)
    metric_counts = _merge_int_maps(metric_counts, rollup_counts)
    primary_metric_votes = _merge_int_maps(primary_metric_votes, rollup_votes)
    mode_counts = _merge_int_maps(mode_counts, rollup_mode_counts)

  summary: dict[str, Any] = {
    "session_count": total_sessions,
    "avg_score": round(total_score / total_sessions, 2),
    "primary_metric_mode": _dominant_metric_mode(mode_counts),
    "primary_metrics": _build_primary_metrics(
      metric_totals,
      metric_counts,
      primary_metric_votes,
      mode_counts,
    ),
  }
  summary.update(_legacy_averages_from_metrics(metric_totals, metric_counts))
  return summary


def _range_bounds(days: int) -> tuple[str, str]:
  today = datetime.now(timezone.utc).date()
  since = today - timedelta(days=days - 1)
  return since.isoformat(), today.isoformat()


def _rollups_in_range(rollups: list[dict[str, Any]], days: int) -> list[dict[str, Any]]:
  since_date, until_date = _range_bounds(days)
  return [item for item in rollups if since_date <= str(item.get("date", "")) <= until_date]


def _streak_days_from_rollups(rollups: list[dict[str, Any]]) -> int:
  if not rollups:
    return 0

  dates_with_sessions = {
    str(item.get("date"))
    for item in rollups
    if _safe_int(item.get("session_count")) > 0
  }
  if not dates_with_sessions:
    return 0

  streak = 0
  cursor = datetime.now(timezone.utc).date()
  while cursor.isoformat() in dates_with_sessions:
    streak += 1
    cursor -= timedelta(days=1)
  return streak


def build_dashboard(user_id: str) -> dict[str, Any]:
  now_ms = int(time() * 1000)
  rollups = _all_rollups(user_id)

  ranges = {
    f"{days}d": _range_summary_from_rollups(_rollups_in_range(rollups, days))
    for days in _RANGE_DAYS
  }

  return {
    "user_id": user_id,
    "total_completed_sessions": sum(_safe_int(item.get("session_count")) for item in rollups),
    "streak_days": _streak_days_from_rollups(rollups),
    "avg_score_7d": ranges["7d"]["avg_score"],
    "last_session_at": max((_safe_int(item.get("last_session_at")) for item in rollups), default=None),
    "ranges": ranges,
    "generated_at": now_ms,
  }


_DASHBOARD_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_TRENDS_CACHE: dict[tuple[str, str], tuple[float, dict[str, Any]]] = {}
_CACHE_TTL_SEC = 300.0


def _invalidate_analytics_cache(user_id: str) -> None:
  _DASHBOARD_CACHE.pop(user_id, None)
  keys_to_remove = [k for k in _TRENDS_CACHE if k[0] == user_id]
  for k in keys_to_remove:
    _TRENDS_CACHE.pop(k, None)


def build_trends(user_id: str, range_key: str) -> dict[str, Any]:
  now = time()
  normalized_range = (range_key or "30d").lower().strip()
  cache_key = (user_id, normalized_range)
  cached = _TRENDS_CACHE.get(cache_key)
  if cached and (now - cached[0]) < _CACHE_TTL_SEC:
    return cached[1]

  now_ms = int(now * 1000)
  days = _RANGE_DAY_MAP.get(normalized_range, 30)
  resolved_range = f"{days}d"

  since_date, until_date = _range_bounds(days)
  repository = get_analytics_repository()
  rollups = repository.list_daily_rollups(user_id, since_date=since_date, until_date=until_date)
  if not rollups:
    rollups = _rollups_in_range(_all_rollups(user_id), days)

  indexed = {str(item.get("date", "")): item for item in rollups}
  today = datetime.now(timezone.utc).date()
  points: list[dict[str, Any]] = []

  for offset in reversed(range(days)):
    target = today - timedelta(days=offset)
    date_key = target.isoformat()
    item = indexed.get(date_key)
    if not item:
      points.append(
        {
          "date": date_key,
          "session_count": 0,
          "avg_score": 0.0,
          "avg_pitch_accuracy": 0.0,
          "avg_timing_accuracy": 0.0,
          "avg_breath_control": 0.0,
          "primary_metric_mode": None,
          "primary_metrics": [],
        }
      )
      continue

    metric_totals, metric_counts, primary_metric_votes, mode_counts = (
      _metrics_state_from_rollup(item)
    )
    point = {
      "date": date_key,
      "session_count": _safe_int(item.get("session_count")),
      "avg_score": round(_safe_float(item.get("avg_score")), 2),
      "primary_metric_mode": _dominant_metric_mode(mode_counts),
      "primary_metrics": _build_primary_metrics(
        metric_totals,
        metric_counts,
        primary_metric_votes,
        mode_counts,
      ),
    }
    point.update(_legacy_averages_from_metrics(metric_totals, metric_counts))
    points.append(point)

  result = {
    "user_id": user_id,
    "range": resolved_range,
    "points": points,
    "generated_at": now_ms,
  }
  _TRENDS_CACHE[cache_key] = (now, result)
  return result


def rebuild_dashboard(user_id: str) -> dict[str, Any]:
  _invalidate_analytics_cache(user_id)
  dashboard = build_dashboard(user_id)
  repository = get_analytics_repository()
  res = repository.upsert_dashboard(user_id, dashboard)
  _DASHBOARD_CACHE[user_id] = (time(), res)
  return res


def get_or_build_dashboard(user_id: str) -> dict[str, Any]:
  now = time()
  cached = _DASHBOARD_CACHE.get(user_id)
  if cached and (now - cached[0]) < _CACHE_TTL_SEC:
    return cached[1]

  repository = get_analytics_repository()
  existing = repository.get_dashboard(user_id)
  if existing:
    _DASHBOARD_CACHE[user_id] = (now, existing)
    return existing
  return rebuild_dashboard(user_id)


def record_completed_session(user_id: str, session: dict[str, Any]) -> dict[str, Any]:
  _invalidate_analytics_cache(user_id)
  rollup = _rollup_from_session(session)
  if not rollup:
    return rebuild_dashboard(user_id)

  date_key = str(rollup["date"])
  repository = get_analytics_repository()
  existing = repository.get_daily_rollup(user_id, date_key)
  merged = _merge_rollups(existing, rollup)
  repository.upsert_daily_rollup(user_id, date_key, merged)
  return rebuild_dashboard(user_id)
