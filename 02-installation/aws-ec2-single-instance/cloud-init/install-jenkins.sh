#!/usr/bin/env bash
#
# Installs Java 21 + Jenkins LTS on Ubuntu 24.04.
#
# Two ways to use it:
#   1. Paste the whole file into EC2 "Advanced details -> User data" at launch.
#   2. Run it by hand on the instance: sudo bash install-jenkins.sh
#
# It is safe to re-run. All output lands in /var/log/jenkins-bootstrap.log,
# and it copies itself to /opt/ultimate-jenkins/install-jenkins.sh so you can
# re-run it from an SSM shell after a failed first boot.
#
# Why this is not just "apt-get install jenkins": on a fresh Ubuntu boot the
# apt-daily and unattended-upgrades timers hold the dpkg lock for the first
# minute or two. A plain apt-get exits non-zero, `set -e` kills the script,
# and the instance comes up with no jenkins.service at all.
set -euo pipefail

# Check root before redirecting output, since writing the log needs root and a
# non-root run would otherwise fail with a confusing "tee: Permission denied".
[ "$(id -u)" -eq 0 ] || { echo "must run as root: sudo bash $0"; exit 1; }

exec > >(tee -a /var/log/jenkins-bootstrap.log) 2>&1
echo "=== jenkins bootstrap started: $(date -Is) ==="

export DEBIAN_FRONTEND=noninteractive

mkdir -p /opt/ultimate-jenkins
if [ -f "$0" ]; then
  install -m 0755 "$0" /opt/ultimate-jenkins/install-jenkins.sh
fi

# Stop the boot-time apt timers so they cannot grab the lock mid-install, then
# wait (bounded) for any in-flight apt run to release it.
#
# Do NOT use "cloud-init status --wait" here: as user data this script is a
# child of cloud-init, so waiting on cloud-init deadlocks the boot forever.
systemctl stop unattended-upgrades.service apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

if command -v fuser >/dev/null 2>&1; then
  for _ in $(seq 1 60); do
    if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 &&
       ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
      break
    fi
    echo "package lock busy; waiting..."
    sleep 5
  done
fi

# Every apt call waits up to 10 minutes for the dpkg lock instead of failing.
APT_OPTS=(-y -o DPkg::Lock::Timeout=600)

retry() {
  local attempt=1
  until "$@"; do
    if [ "${attempt}" -ge 5 ]; then
      echo "FAILED after ${attempt} attempts: $*"
      return 1
    fi
    echo "attempt ${attempt} failed, retrying in $((attempt * 10))s: $*"
    sleep "$((attempt * 10))"
    attempt=$((attempt + 1))
  done
}

# A previous failed run can leave a Jenkins apt entry whose key is missing or
# expired. That entry breaks EVERY later apt-get update -- including the one
# below, before the key-fixing code further down ever runs. Start clean.
rm -f /etc/apt/sources.list.d/jenkins.list /usr/share/keyrings/jenkins-keyring.asc

echo "--- installing Java and prerequisites ---"
retry apt-get update "${APT_OPTS[@]}"
retry apt-get install "${APT_OPTS[@]}" \
  ca-certificates curl gnupg fontconfig openjdk-21-jre-headless

echo "--- adding the Jenkins apt repository ---"

# Jenkins rotates its signing key and the old one EXPIRES. The widely-copied
# "jenkins.io-2023.key" expired on 2026-03-26; using it makes apt fail with
# NO_PUBKEY / "repository is not signed". Try this year's key, then next
# year's, then the last known-good one, and take the first that is not expired.
KEY_DEST=/usr/share/keyrings/jenkins-keyring.asc
YEAR=$(date +%Y)
KEY_FOUND=""

for KEY_NAME in "jenkins.io-${YEAR}.key" "jenkins.io-$((YEAR + 1)).key" "jenkins.io-2026.key"; do
  if ! curl -fsSL --retry 3 --retry-delay 5 \
    "https://pkg.jenkins.io/debian-stable/${KEY_NAME}" -o "${KEY_DEST}" 2>/dev/null; then
    continue
  fi
  # Column 2 of gpg's colon output is validity; "e" means expired.
  VALIDITY=$(gpg --show-keys --with-colons "${KEY_DEST}" 2>/dev/null | awk -F: '/^pub/{print $2; exit}')
  if [ -n "${VALIDITY}" ] && [ "${VALIDITY}" != "e" ]; then
    echo "using signing key: ${KEY_NAME}"
    KEY_FOUND="${KEY_NAME}"
    break
  fi
done

if [ -z "${KEY_FOUND}" ]; then
  rm -f "${KEY_DEST}"
  echo "ERROR: no valid Jenkins signing key found; check the current key name at"
  echo "       https://www.jenkins.io/doc/book/installing/linux/"
  exit 1
fi

echo "deb [signed-by=${KEY_DEST}] https://pkg.jenkins.io/debian-stable binary/" \
  >/etc/apt/sources.list.d/jenkins.list

echo "--- installing Jenkins ---"
retry apt-get update "${APT_OPTS[@]}"
retry apt-get install "${APT_OPTS[@]}" jenkins

systemctl enable --now jenkins

echo "--- waiting for Jenkins to answer on :8080 ---"
timeout 300 bash -c 'until curl -fsS -o /dev/null http://127.0.0.1:8080/login; do sleep 5; done'

systemctl is-active --quiet jenkins
echo "=== jenkins bootstrap finished: $(date -Is) ==="
touch /var/log/jenkins-bootstrap.done
