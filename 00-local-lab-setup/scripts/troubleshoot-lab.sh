#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== docker compose ps =="
docker compose -f "${ROOT_DIR}/docker-compose.yml" ps || true
echo
echo "== jenkins logs =="
docker compose -f "${ROOT_DIR}/docker-compose.yml" logs --tail=80 jenkins || true
echo
echo "== agent logs =="
docker compose -f "${ROOT_DIR}/docker-compose.yml" logs --tail=80 agent || true
echo
echo "== gitea logs =="
docker compose -f "${ROOT_DIR}/docker-compose.yml" logs --tail=40 gitea || true
echo
echo "== registry logs =="
docker compose -f "${ROOT_DIR}/docker-compose.yml" logs --tail=40 registry || true
