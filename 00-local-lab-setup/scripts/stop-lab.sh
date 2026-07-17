#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "[info] Stopping lab containers and preserving data volumes"
docker compose -f "${ROOT_DIR}/docker-compose.yml" down
