#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y ca-certificates curl gnupg openjdk-21-jdk
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" >/etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins
