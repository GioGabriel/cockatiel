#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend/vocal_coach_api"
MOBILE_DIR="${ROOT_DIR}/mobile/vocal_coach_app"

export PATH="${HOME}/flutter/bin:${HOME}/.pub-cache/bin:${PATH}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${HOME}/Library/Android/sdk}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin"

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8000}"
EMULATOR_NAME="${EMULATOR_NAME:-Pixel_6a}"
DEVICE_ID="${DEVICE_ID:-}"
BACKEND_START_SCRIPT="${BACKEND_START_SCRIPT:-scripts/run_backend_async.sh}"

START_BACKEND="${START_BACKEND:-true}"
START_EMULATOR="${START_EMULATOR:-true}"
RUN_FLUTTER="${RUN_FLUTTER:-true}"
FLUTTER_EXTRA_ARGS="${FLUTTER_EXTRA_ARGS:-}"

BACKEND_PID=""
BACKEND_STARTED="false"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    exit 1
  fi
}

wait_for_url() {
  local url="$1"
  local timeout_s="$2"
  local elapsed=0
  while ! curl -fsS "$url" >/dev/null 2>&1; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [[ "$elapsed" -ge "$timeout_s" ]]; then
      echo "Timed out waiting for $url" >&2
      return 1
    fi
  done
}

first_emulator_device() {
  local line
  while IFS= read -r line; do
    case "$line" in
      emulator-*"device")
        printf '%s\n' "${line%%$'\t'*}"
        return 0
        ;;
    esac
  done < <(adb devices)
  return 1
}

cleanup() {
  if [[ "$BACKEND_STARTED" == "true" && -n "$BACKEND_PID" ]]; then
    if kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
      kill "$BACKEND_PID" >/dev/null 2>&1 || true
    fi
  fi
}

trap cleanup EXIT INT TERM

require_cmd curl
require_cmd flutter
require_cmd adb

if [[ "$START_EMULATOR" == "true" ]]; then
  echo "Launching Android emulator: ${EMULATOR_NAME}"
  (cd "$MOBILE_DIR" && flutter emulators --launch "$EMULATOR_NAME" >/dev/null 2>&1 || true)
fi

if [[ -z "$DEVICE_ID" ]]; then
  for _ in $(seq 1 45); do
    if DEVICE_ID="$(first_emulator_device 2>/dev/null || true)" && [[ -n "$DEVICE_ID" ]]; then
      break
    fi
    sleep 1
  done
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No Android emulator device found. Start one and retry." >&2
  exit 1
fi

if [[ "$START_BACKEND" == "true" ]]; then
  if curl -fsS "${BACKEND_URL%/}/health" >/dev/null 2>&1; then
    echo "Backend already running at ${BACKEND_URL}."
  else
    echo "Starting backend..."
    (
      cd "$BACKEND_DIR"
      # This helper is explicitly local-only. Production still hard-disables
      # bypass in app/core/config.py even if the variable is inherited.
      AUTH_BYPASS="${AUTH_BYPASS:-true}" bash "$BACKEND_START_SCRIPT"
    ) &
    BACKEND_PID="$!"
    BACKEND_STARTED="true"
    wait_for_url "${BACKEND_URL%/}/health" 60
  fi
fi

echo "Using Android device: ${DEVICE_ID}"
echo "Backend: ${BACKEND_URL}"

if [[ "$RUN_FLUTTER" == "true" ]]; then
  cd "$MOBILE_DIR"
  if [[ -n "$FLUTTER_EXTRA_ARGS" ]]; then
    # shellcheck disable=SC2086
    flutter run -d "$DEVICE_ID" $FLUTTER_EXTRA_ARGS
  else
    flutter run -d "$DEVICE_ID"
  fi
fi

echo "All services are ready."
