#!/usr/bin/env bash
set -euo pipefail

LOCAL_PORT="${1:-8080}"
curl -fsS "http://127.0.0.1:${LOCAL_PORT}/login" >/dev/null
echo "[pass] Jenkins login page reachable on local port ${LOCAL_PORT}"
