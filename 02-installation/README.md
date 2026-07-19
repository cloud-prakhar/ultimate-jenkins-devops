# 02 — Jenkins Installation

## Overview

This section covers every major method for installing Jenkins — from a simple local setup to production-grade Docker and Kubernetes deployments. You will learn to install, configure, and validate Jenkins across multiple environments.

## Status

| Content | Status |
| --- | --- |
| General installation guidance | ✅ Available |
| [AWS EC2 single-instance live-demo lab](./aws-ec2-single-instance/README.md) | ✅ Available |
| Additional installation tracks in this module | 🚧 In Progress |

---

## Objectives

- Install Jenkins using multiple methods
- Configure Jenkins post-installation
- Understand Jenkins directory structure
- Set up initial admin credentials securely
- Install essential plugins
- Configure the system (JDK, Maven, credentials)
- Run Jenkins in Docker for local development
- Deploy Jenkins on Kubernetes for production

---

## Prerequisites

- Linux fundamentals (Ubuntu/RHEL commands)
- Basic Docker knowledge
- Basic Kubernetes knowledge (for K8s section)
- Java 17 or 21 installed (for bare-metal install)

---

## Installation Methods

| Method | Environment | Complexity | Recommended For |
|--------|-------------|-----------|-----------------|
| WAR file | Any OS | Low | Quick testing only |
| Package Manager (apt/yum) | Linux | Low | Dev/Staging |
| Docker | Any OS | Low-Medium | Local dev |
| Docker Compose | Any OS | Medium | Team dev environments |
| Kubernetes (Helm) | K8s cluster | High | Production |
| CloudBees CI | Cloud/K8s | High | Enterprise |

---

## Method 1: Package Manager Installation (Ubuntu)

### Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 21
sudo apt install -y openjdk-21-jdk

# Verify Java
java -version
# Expected: openjdk version "21.x.x"
```

### Install Jenkins

> **Key rotation:** Jenkins publishes a new signing key every few years and the
> old one expires — `jenkins.io-2023.key`, still quoted by many guides online,
> expired on **2026-03-26**. If `apt update` reports `NO_PUBKEY` or "repository
> is not signed", you are using an expired key; fetch the current
> `jenkins.io-<year>.key` instead. The scripts in this repo detect this
> automatically.

```bash
# Add Jenkins GPG key (verified current as of 2026-07-19)
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

# Add Jenkins repository
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install
sudo apt update
sudo apt install -y jenkins

# Start and enable Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Verify status
sudo systemctl status jenkins
```

### Validate Installation

```bash
# Check Jenkins is running
curl -I http://localhost:8080

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Open Browser

Navigate to: `http://localhost:8080`

Enter the initial admin password from the command above.

---

## Method 2: Package Manager Installation (RHEL/CentOS/Amazon Linux)

```bash
# Install Java
sudo dnf install -y java-21-openjdk-devel

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import GPG key (see the key-rotation note above; 2023 key expired 2026-03-26)
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2026.key

# Install
sudo dnf install -y jenkins

# Start and enable
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Verify
sudo systemctl status jenkins
```

---

## Method 3: Docker (Local Development)

This is the **recommended approach for local development** — clean, isolated, reproducible.

### Run Jenkins in Docker

```bash
# Create a persistent volume for Jenkins data
docker volume create jenkins-data

# Run Jenkins
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts-jdk21

# Check logs for initial password
docker logs jenkins 2>&1 | grep -A 3 "Please use the following password"

# Or directly
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

> **Note:** Mounting `/var/run/docker.sock` allows Jenkins to run Docker commands — required for Docker-in-Docker builds.

### Custom Jenkins Dockerfile

For teams, build a custom image with plugins pre-installed:

```dockerfile
FROM jenkins/jenkins:lts-jdk21

# Disable setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Install plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy JCasC configuration
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml
```

```text
# plugins.txt — Essential plugins
git:latest
pipeline-stage-view:latest
blueocean:latest
kubernetes:latest
docker-workflow:latest
credentials-binding:latest
role-strategy:latest
ansicolor:latest
timestamper:latest
build-timeout:latest
ws-cleanup:latest
junit:latest
configuration-as-code:latest
job-dsl:latest
prometheus:latest
email-ext:latest
slack:latest
```

---

## Method 4: Docker Compose (Team Development)

```yaml
# docker-compose.yml
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts-jdk21
    container_name: jenkins
    restart: unless-stopped
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Xmx2g -Xms512m
      - CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs
    networks:
      - jenkins-network

  jenkins-agent:
    image: jenkins/inbound-agent:latest
    container_name: jenkins-agent
    restart: unless-stopped
    environment:
      - JENKINS_URL=http://jenkins:8080
      - JENKINS_SECRET=${JENKINS_AGENT_SECRET}
      - JENKINS_AGENT_NAME=docker-agent-1
    depends_on:
      - jenkins
    networks:
      - jenkins-network

volumes:
  jenkins-data:

networks:
  jenkins-network:
    driver: bridge
```

```bash
# Start
docker-compose up -d

# View logs
docker-compose logs -f jenkins

# Stop
docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v
```

---

## Method 5: Kubernetes with Helm (Production)

This is the **recommended production approach**. Covered in detail in [10-kubernetes-integration](../10-kubernetes-integration/README.md).

### Quick Start

```bash
# Add Jenkins Helm repository
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Create namespace
kubectl create namespace jenkins

# Create values file
cat > jenkins-values.yaml << 'EOF'
controller:
  image: "jenkins/jenkins"
  tag: "lts-jdk21"
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
  serviceType: ClusterIP
  installPlugins:
    - git:latest
    - pipeline-stage-view:latest
    - kubernetes:latest
    - docker-workflow:latest
    - configuration-as-code:latest
    - role-strategy:latest
    - prometheus:latest
  JCasC:
    enabled: true
persistence:
  enabled: true
  size: 20Gi
  storageClass: "standard"
agent:
  enabled: true
  defaultsProviderTemplate: ""
  namespace: jenkins
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
EOF

# Install Jenkins
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --values jenkins-values.yaml \
  --wait

# Get admin password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password
```

---

## Post-Installation Configuration

### Step 1: Unlock Jenkins

1. Navigate to `http://localhost:8080`
2. Enter the initial admin password
3. Click "Install suggested plugins" (or "Select plugins to install" for custom set)
4. Create admin user with a strong password
5. Configure Jenkins URL

### Step 2: Configure System

Navigate to **Manage Jenkins → System**:

| Setting | Value |
|---------|-------|
| Jenkins URL | `https://jenkins.yourdomain.com/` |
| System Admin email | `jenkins@yourdomain.com` |
| # of executors (controller) | `0` (never build on controller) |

### Step 3: Configure Tools

Navigate to **Manage Jenkins → Tools**:

```text
JDK Installations:
  Name: JDK-21
  Install automatically: ✅
  Version: Java 21

Maven Installations:
  Name: Maven-3.9
  Install automatically: ✅
  Version: 3.9.6

Node.js Installations:
  Name: Node-20
  Install automatically: ✅
  Version: 20.x

Git:
  Name: Default Git
  Path: /usr/bin/git
```

### Step 4: Configure Credentials

Navigate to **Manage Jenkins → Credentials → System → Global credentials**:

```text
Kind: Username with password
Scope: Global
Username: your-github-username
Password: your-github-token
ID: github-credentials
Description: GitHub PAT for SCM operations
```

```text
Kind: Secret text
Scope: Global
Secret: your-docker-hub-token
ID: dockerhub-token
Description: Docker Hub access token
```

### Step 5: Install Essential Plugins

Navigate to **Manage Jenkins → Plugins → Available plugins**:

Search and install:

- Blue Ocean
- Kubernetes
- Docker Pipeline
- Role-based Authorization Strategy
- AnsiColor
- Timestamper
- Build Timeout
- Workspace Cleanup
- SonarQube Scanner
- Slack Notification

---

## Jenkins Directory Structure

```text
/var/jenkins_home/           (or JENKINS_HOME)
├── config.xml               ← Jenkins system configuration
├── credentials.xml          ← Encrypted credentials store
├── secrets/
│   ├── initialAdminPassword ← First-run password (deleted after setup)
│   ├── master.key          ← Master encryption key
│   └── hudson.util.Secret  ← Secret key
├── plugins/                 ← Installed plugins (.jpi files)
├── jobs/                    ← Job configurations and build history
│   └── my-job/
│       ├── config.xml      ← Job configuration
│       └── builds/
│           └── 1/
│               ├── build.xml
│               └── log
├── workspace/               ← Build workspaces (one per job per agent)
├── users/                   ← User accounts
├── nodes/                   ← Agent configurations
├── logs/                    ← Jenkins system logs
└── casc_configs/            ← JCasC configuration files
```

---

## Security Hardening (Post-Installation)

```bash
# 1. Disable old/unused CLI (if not needed)
# Manage Jenkins → Security → Disable CLI over Remoting

# 2. Enable CSRF Protection
# Manage Jenkins → Security → CSRF Protection → Enable

# 3. Configure Security Realm
# Manage Jenkins → Security → Security Realm → Jenkins own user database

# 4. Configure Authorization
# Manage Jenkins → Security → Authorization → Role-Based Strategy

# 5. Agent-to-Controller security
# Manage Jenkins → Security → Agent → Enable Agent ↔ Controller Security
```

---

## Validation

```bash
# Check Jenkins process
ps aux | grep jenkins

# Check port is listening
ss -tlnp | grep 8080

# Check Jenkins API
curl -s http://localhost:8080/api/json | python3 -m json.tool

# Check Jenkins version
curl -s -I http://localhost:8080 | grep X-Jenkins

# Run a test pipeline
# Create a job with: echo "Jenkins is working"
```

---

## Troubleshooting

### Jenkins Won't Start

```bash
# Check Java version (must be 17 or 21)
java -version

# Check Jenkins logs
sudo journalctl -u jenkins -f
# or
docker logs jenkins -f

# Check port conflict
ss -tlnp | grep 8080
```

### Out of Memory Errors

```bash
# Increase heap size
# Edit /etc/default/jenkins
JAVA_OPTS="-Xmx4g -Xms1g -XX:+UseG1GC"

# Or Docker
docker run -e JAVA_OPTS="-Xmx4g" ...
```

### Plugin Installation Fails

```bash
# Use Jenkins Plugin CLI directly
jenkins-plugin-cli --plugin-file plugins.txt

# Or update the site URL in Manage Jenkins → Plugin Manager → Advanced → Update Site
# Use: https://updates.jenkins.io/update-center.json
```

### Agent Won't Connect

```bash
# Check agent logs
# Check firewall rules (port 50000 for JNLP)
sudo ufw allow 50000/tcp

# For SSH agents, check SSH connectivity
ssh -v jenkins-agent.example.com

# Verify agent secret matches in controller
```

---

## Cleanup

```bash
# Docker
docker stop jenkins && docker rm jenkins
docker volume rm jenkins-data

# Docker Compose
docker-compose down -v

# Ubuntu package
sudo systemctl stop jenkins
sudo apt remove --purge jenkins
sudo rm -rf /var/lib/jenkins
sudo rm -rf /var/log/jenkins

# Kubernetes
helm uninstall jenkins -n jenkins
kubectl delete namespace jenkins
```

---

## Best Practices

1. **Never run builds on the controller** — set controller executors to 0
2. **Use JCasC** — never configure Jenkins manually; use Configuration as Code
3. **Pin plugin versions** — use specific versions in plugins.txt, not `latest`
4. **Use a dedicated Jenkins user** — never run Jenkins as root
5. **Mount Docker socket carefully** — alternative: use Kaniko or Buildah for rootless builds
6. **Use HTTPS** — always terminate TLS at the load balancer or ingress
7. **Backup JENKINS_HOME** — back up before every plugin update
8. **Monitor memory** — Jenkins is a JVM application; tune heap carefully
9. **Keep Jenkins updated** — security patches are released regularly

---

## References

- [Jenkins Installation Guide](https://www.jenkins.io/doc/book/installing/)
- [Jenkins Docker Image](https://hub.docker.com/r/jenkins/jenkins)
- [Jenkins Helm Chart](https://github.com/jenkinsci/helm-charts)
- [JCasC Plugin](https://www.jenkins.io/projects/jcasc/)
- [Jenkins Plugin Index](https://plugins.jenkins.io/)
- [Jenkins Security Advisories](https://www.jenkins.io/security/advisories/)

---

## Next Section

[03 — Jenkins UI →](../03-jenkins-ui/README.md)
