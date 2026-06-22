#!/usr/bin/env bash

set -euo pipefail

export AI_ASYNC_ENABLED="true"
export AI_WORKER_ENABLED="${AI_WORKER_ENABLED:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/run_backend.sh"
