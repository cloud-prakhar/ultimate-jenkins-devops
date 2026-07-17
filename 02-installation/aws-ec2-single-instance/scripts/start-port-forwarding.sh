#!/usr/bin/env bash
set -euo pipefail

INSTANCE_ID="${1:?Usage: start-port-forwarding.sh <instance-id> [local-port] [remote-port]}"
LOCAL_PORT="${2:-8080}"
REMOTE_PORT="${3:-8080}"

aws ssm start-session \
  --target "${INSTANCE_ID}" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
