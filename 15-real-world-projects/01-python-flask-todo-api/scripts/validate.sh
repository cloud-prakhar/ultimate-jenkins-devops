#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv
# shellcheck source=/dev/null
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
flake8 app tests
black --check app tests
pytest tests --cov=app --cov-fail-under=80
docker build -t flask-todo-api:validate .
docker run -d --rm --name flask-todo-api-validate flask-todo-api:validate
sleep 5
docker exec flask-todo-api-validate python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')"
docker rm -f flask-todo-api-validate >/dev/null 2>&1 || true
docker rmi flask-todo-api:validate >/dev/null 2>&1 || true
echo "[pass] Validation complete"
