#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" != "--yes" ]]; then
  echo "[warn] This removes lab containers and volumes."
  echo "[warn] Re-run with --yes to continue."
  exit 1
fi

echo "[info] Removing lab containers, images, and volumes"
docker compose -f "${ROOT_DIR}/docker-compose.yml" down -v --remove-orphans
