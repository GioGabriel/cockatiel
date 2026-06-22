#!/usr/bin/env python3

import argparse
from datetime import datetime, timedelta, timezone
import json
import os
import sys
import time
import urllib.error
import urllib.request


def _request_json(
  method: str,
  url: str,
  headers: dict[str, str],
  payload: dict | None = None,
  timeout_s: int = 30,
) -> dict:
  body = None
  if payload is not None:
    body = json.dumps(payload).encode("utf-8")

  request = urllib.request.Request(url=url, method=method, data=body, headers=headers)
  try:
    with urllib.request.urlopen(request, timeout=timeout_s) as response:
      raw = response.read().decode("utf-8")
      if not raw:
        return {}
      return json.loads(raw)
  except urllib.error.HTTPError as exc:
    error_body = exc.read().decode("utf-8") if exc.fp else ""
    raise RuntimeError(f"{method} {url} failed ({exc.code}): {error_body}") from exc
  except urllib.error.URLError as exc:
    raise RuntimeError(f"{method} {url} failed: {exc.reason}") from exc


def _metric_frame(session_id: str, exercise_type: str, step: int, timestamp_ms: int) -> dict:
  base = 68 + (step * 2)
  return {
    "session_id": session_id,
    "timestamp_ms": timestamp_ms,
    "exercise_type": exercise_type,
    "pitch_accuracy": min(base + 2, 100),
    "timing_accuracy": min(base + 1, 100),
    "breath_control": min(base, 100),
    "pitch_stability": min(base + 1, 100),
    "vibrato_consistency": min(base - 3, 100),
    "note_transition_smoothness": min(base + 2, 100),
  }


def _session_day_offset(index: int, spread_days: int) -> int:
  if spread_days <= 1:
    return 0
  return (spread_days - 1) - (index % spread_days)


def _session_anchor_timestamp_ms(index: int, spread_days: int) -> int:
  now = datetime.now(timezone.utc)
  target_day = now.date() - timedelta(days=_session_day_offset(index, spread_days))
  target = datetime(
    year=target_day.year,
    month=target_day.month,
    day=target_day.day,
    hour=12,
    minute=0,
    second=0,
    microsecond=0,
    tzinfo=timezone.utc,
  )
  if target >= now:
    target = now - timedelta(minutes=1)
  return int(target.timestamp() * 1000)


def _resolve_feedback(
  *,
  normalized_base_url: str,
  headers: dict[str, str],
  session_id: str,
  finalized: dict,
  wait_timeout_s: int,
) -> dict:
  feedback = finalized.get("feedback")
  if isinstance(feedback, dict):
    return feedback

  status = str(finalized.get("status", ""))
  if status != "processing":
    return {}

  deadline = time.time() + max(wait_timeout_s, 1)
  while time.time() < deadline:
    session = _request_json("GET", f"{normalized_base_url}/v1/sessions/{session_id}", headers)
    session_feedback = session.get("feedback")
    if isinstance(session_feedback, dict):
      return session_feedback
    if session.get("status") == "failed":
      return {"model_used": "failed", "failure_reason": session.get("failure_reason")}
    time.sleep(1)

  return {"model_used": "processing-timeout"}


def run_seed(
  base_url: str,
  auth_token: str,
  session_count: int,
  metrics_per_session: int,
  spread_days: int,
  wait_timeout_s: int,
) -> None:
  normalized_base_url = base_url.rstrip("/")
  headers = {
    "Authorization": f"Bearer {auth_token}",
    "Content-Type": "application/json",
  }

  _request_json("GET", f"{normalized_base_url}/health", headers={"Content-Type": "application/json"})

  plans = [
    ("training", "warmup_pitch"),
    ("training", "breath_support_ladder"),
    ("karaoke", "karaoke_timing_focus"),
  ]

  for idx in range(session_count):
    mode, exercise_type = plans[idx % len(plans)]
    anchor_timestamp_ms = _session_anchor_timestamp_ms(idx, spread_days)
    created = _request_json(
      "POST",
      f"{normalized_base_url}/v1/sessions",
      headers,
      {"mode": mode, "exercise_type": exercise_type},
    )
    session_id = created["session_id"]

    metrics = [
      _metric_frame(
        session_id,
        exercise_type,
        step,
        anchor_timestamp_ms + (step * 1000),
      )
      for step in range(metrics_per_session)
    ]
    _request_json(
      "POST",
      f"{normalized_base_url}/v1/sessions/{session_id}/metrics",
      headers,
      {"metrics": metrics},
    )

    finalized = _request_json(
      "POST",
      f"{normalized_base_url}/v1/sessions/{session_id}/finalize",
      headers,
      timeout_s=max(wait_timeout_s, 30),
    )
    feedback = _resolve_feedback(
      normalized_base_url=normalized_base_url,
      headers=headers,
      session_id=session_id,
      finalized=finalized,
      wait_timeout_s=wait_timeout_s,
    )
    model_used = feedback.get("model_used", "n/a")
    session_day = datetime.fromtimestamp(anchor_timestamp_ms / 1000, tz=timezone.utc).date().isoformat()
    print(
      f"seeded session={session_id} day={session_day} mode={mode} exercise={exercise_type} model={model_used}"
    )

  dashboard = _request_json(
    "GET",
    f"{normalized_base_url}/v1/analytics/dashboard",
    headers,
  )
  print("\nAnalytics dashboard:")
  print(json.dumps(dashboard, indent=2, sort_keys=True))


def main() -> int:
  parser = argparse.ArgumentParser(description="Seed sessions and print analytics dashboard.")
  parser.add_argument("--base-url", default=os.getenv("BASE_URL", "http://127.0.0.1:8000"))
  parser.add_argument("--auth-token", default=os.getenv("AUTH_TOKEN", "dev_seed-user"))
  parser.add_argument("--sessions", type=int, default=int(os.getenv("SESSION_COUNT", "3")))
  parser.add_argument("--metrics-per-session", type=int, default=int(os.getenv("METRICS_PER_SESSION", "3")))
  parser.add_argument("--spread-days", type=int, default=int(os.getenv("SPREAD_DAYS", "1")))
  parser.add_argument("--wait-timeout-s", type=int, default=int(os.getenv("WAIT_TIMEOUT_S", "90")))
  args = parser.parse_args()

  if args.sessions < 1:
    print("--sessions must be >= 1", file=sys.stderr)
    return 2
  if args.metrics_per_session < 1:
    print("--metrics-per-session must be >= 1", file=sys.stderr)
    return 2
  if args.spread_days < 1:
    print("--spread-days must be >= 1", file=sys.stderr)
    return 2
  if args.wait_timeout_s < 1:
    print("--wait-timeout-s must be >= 1", file=sys.stderr)
    return 2

  try:
    run_seed(
      args.base_url,
      args.auth_token,
      args.sessions,
      args.metrics_per_session,
      args.spread_days,
      args.wait_timeout_s,
    )
  except Exception as exc:
    print(f"seed failed: {exc}", file=sys.stderr)
    return 1
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
