#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_NAME="jenkins-home-$(date +%Y%m%d-%H%M%S).tar.gz"
sudo tar -C /var/lib -czf "${ARCHIVE_NAME}" jenkins
echo "[pass] Created ${ARCHIVE_NAME}"
