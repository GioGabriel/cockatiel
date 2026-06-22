#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
AUTH_TOKEN="${AUTH_TOKEN:-dev_seed-user}"

echo "== Health =="
curl -sS "${BASE_URL%/}/health" | python3 -m json.tool

echo
echo "== Current User =="
curl -sS \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  "${BASE_URL%/}/v1/auth/me" | python3 -m json.tool

echo
echo "== Analytics Dashboard =="
curl -sS \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  "${BASE_URL%/}/v1/analytics/dashboard" | python3 -m json.tool

echo
echo "== Analytics Trends (7d) =="
curl -sS \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  "${BASE_URL%/}/v1/analytics/trends?range=7d" | python3 -m json.tool
