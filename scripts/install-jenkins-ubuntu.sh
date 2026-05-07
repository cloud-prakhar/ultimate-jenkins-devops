#!/bin/bash
# Jenkins Installation Script for Ubuntu 22.04/24.04
# Usage: sudo bash install-jenkins-ubuntu.sh
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
JENKINS_PORT="${JENKINS_PORT:-8080}"
JAVA_VERSION="${JAVA_VERSION:-21}"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Prerequisites ────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || error "This script must be run as root. Use: sudo $0"

# ─── System Update ────────────────────────────────────────────────────────────
info "Updating system packages..."
apt-get update -q
apt-get upgrade -y -q

# ─── Install Java ─────────────────────────────────────────────────────────────
info "Installing Java ${JAVA_VERSION}..."
apt-get install -y -q "openjdk-${JAVA_VERSION}-jdk"
java -version 2>&1 | grep -o 'version "[^"]*"' | head -1

# ─── Add Jenkins Repository ───────────────────────────────────────────────────
info "Adding Jenkins repository..."
apt-get install -y -q ca-certificates curl

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" | \
    tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# ─── Install Jenkins ──────────────────────────────────────────────────────────
info "Installing Jenkins..."
apt-get update -q
apt-get install -y -q jenkins

# ─── Configure Port ───────────────────────────────────────────────────────────
if [ "${JENKINS_PORT}" != "8080" ]; then
    info "Configuring Jenkins to use port ${JENKINS_PORT}..."
    sed -i "s/HTTP_PORT=8080/HTTP_PORT=${JENKINS_PORT}/" /etc/default/jenkins
fi

# ─── Start Jenkins ────────────────────────────────────────────────────────────
info "Starting Jenkins service..."
systemctl daemon-reload
systemctl start jenkins
systemctl enable jenkins

# ─── Wait for Jenkins ─────────────────────────────────────────────────────────
info "Waiting for Jenkins to start..."
timeout 120 bash -c "until curl -s http://localhost:${JENKINS_PORT}/login > /dev/null; do sleep 5; done"

# ─── Display Results ──────────────────────────────────────────────────────────
INITIAL_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "NOT FOUND")

echo ""
echo "=========================================="
echo "   Jenkins Installation Complete!"
echo "=========================================="
echo ""
echo "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):${JENKINS_PORT}"
echo ""
echo "Initial Admin Password:"
echo "  ${INITIAL_PASSWORD}"
echo ""
echo "Or get it with:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "Jenkins Status:"
systemctl status jenkins --no-pager | grep -E "Active:|Main PID:"
echo ""
info "Installation complete!"
