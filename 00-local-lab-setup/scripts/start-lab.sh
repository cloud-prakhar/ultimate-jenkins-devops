#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] Missing required tool: $1" >&2
    exit 1
  }
}

require_tool docker

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose v2 is required" >&2
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  echo "[error] ${ROOT_DIR}/.env not found. Copy .env.example first." >&2
  exit 1
fi

echo "[info] Building and starting the local lab"
docker compose -f "${ROOT_DIR}/docker-compose.yml" up -d --build

echo "[info] Waiting for services to initialize"
sleep 10

"${ROOT_DIR}/scripts/verify-lab.sh"
