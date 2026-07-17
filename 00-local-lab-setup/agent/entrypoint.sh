#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="${JENKINS_URL:?JENKINS_URL is required}"
JENKINS_ADMIN_ID="${JENKINS_ADMIN_ID:?JENKINS_ADMIN_ID is required}"
JENKINS_ADMIN_PASSWORD="${JENKINS_ADMIN_PASSWORD:?JENKINS_ADMIN_PASSWORD is required}"
AGENT_NAME="${AGENT_NAME:?AGENT_NAME is required}"
AGENT_WORKDIR="${AGENT_WORKDIR:-/home/jenkins/agent}"

log() {
  printf '[agent] %s\n' "$*"
}

wait_for_jenkins() {
  log "Waiting for Jenkins at ${JENKINS_URL}"
  for _ in $(seq 1 60); do
    if curl -fsS "${JENKINS_URL}/login" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  log "Timed out waiting for Jenkins"
  exit 1
}

get_secret() {
  curl -fsS -u "${JENKINS_ADMIN_ID}:${JENKINS_ADMIN_PASSWORD}" \
    "${JENKINS_URL}/computer/${AGENT_NAME}/jenkins-agent.jnlp" |
    sed -n 's/.*<argument>\([^<]*\)<\/argument>.*/\1/p' | sed -n '1p'
}

wait_for_jenkins

mkdir -p "${AGENT_WORKDIR}"

for _ in $(seq 1 30); do
  SECRET="$(get_secret || true)"
  if [[ -n "${SECRET}" ]]; then
    export JENKINS_SECRET="${SECRET}"
    export JENKINS_AGENT_NAME="${AGENT_NAME}"
    log "Starting inbound agent ${AGENT_NAME}"
    exec /usr/local/bin/jenkins-agent
  fi
  log "Agent secret not available yet. Retrying."
  sleep 5
done

log "Unable to retrieve agent secret for ${AGENT_NAME}"
exit 1
