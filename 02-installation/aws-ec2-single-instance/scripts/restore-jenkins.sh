#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:?Usage: restore-jenkins.sh <archive-path>}"
sudo systemctl stop jenkins
sudo tar -C /var/lib -xzf "${ARCHIVE}"
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo systemctl start jenkins
echo "[pass] Restore complete"
