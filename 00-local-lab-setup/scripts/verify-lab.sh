#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() {
  printf '[pass] %s\n' "$*"
}

fail() {
  printf '[fail] %s\n' "$*" >&2
  exit 1
}

check_http() {
  local name="$1"
  local url="$2"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"
  if [[ "$code" =~ ^(200|302|403)$ ]]; then
    pass "${name} reachable at ${url} (HTTP ${code})"
  else
    fail "${name} not reachable at ${url} (HTTP ${code:-none})"
  fi
}

echo "[info] Checking Docker Compose service state"
docker compose -f "${ROOT_DIR}/docker-compose.yml" ps

check_http "Jenkins" "http://localhost:8080/login"
check_http "Gitea" "http://localhost:3000/"
check_http "Registry" "http://localhost:5000/v2/"

if docker compose -f "${ROOT_DIR}/docker-compose.yml" ps agent | grep -q "Up"; then
  pass "Agent container is running"
else
  fail "Agent container is not running"
fi

if docker compose -f "${ROOT_DIR}/docker-compose.yml" logs jenkins 2>/dev/null | grep -q "local-linux-agent"; then
  pass "Jenkins knows about the local agent"
else
  fail "Jenkins logs do not show the local agent yet"
fi
