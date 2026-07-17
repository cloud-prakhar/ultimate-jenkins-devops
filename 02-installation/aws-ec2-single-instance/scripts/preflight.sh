#!/usr/bin/env bash
set -euo pipefail

for tool in aws session-manager-plugin terraform; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "[error] Missing tool: $tool" >&2
    exit 1
  }
done

aws sts get-caller-identity >/dev/null
terraform -chdir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/terraform" fmt -check
echo "[pass] AWS CLI, Session Manager plugin, and Terraform are available"
