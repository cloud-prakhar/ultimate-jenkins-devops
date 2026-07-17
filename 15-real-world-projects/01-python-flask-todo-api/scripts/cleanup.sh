#!/usr/bin/env bash
set -euo pipefail

docker rm -f flask-todo-api-demo flask-todo-api-smoke flask-todo-api-validate >/dev/null 2>&1 || true
docker rmi localhost:5000/flask-todo-api:latest >/dev/null 2>&1 || true
find . -maxdepth 1 -type d -name ".venv" -exec rm -rf {} +
rm -rf .pytest_cache htmlcov test-results coverage.xml
echo "[pass] Cleanup complete"
