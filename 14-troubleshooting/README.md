# 14 — Troubleshooting

## Overview

Jenkins troubleshooting is a critical skill. This section covers systematic approaches to diagnosing and resolving common Jenkins issues — from build failures and agent problems to performance issues and plugin conflicts.

## Practical Lab

Use the dedicated [debugging lab](./debugging-lab/README.md) for hands-on failure scenarios.

---

## Troubleshooting Methodology

```
1. OBSERVE     → What is the symptom? (error message, behavior)
2. LOCATE      → Where is it happening? (controller, agent, pipeline stage)
3. IDENTIFY    → What changed recently? (plugin update, config change, code change)
4. ISOLATE     → Reproduce in minimal environment
5. FIX         → Apply targeted fix
6. VERIFY      → Confirm fix works
7. DOCUMENT    → Record cause and solution
```

---

## 1. Jenkins Won't Start

### Symptom
Jenkins service fails to start or crashes immediately after startup.

### Diagnosis

```bash
# Check Java version (must be 17 or 21)
java -version

# Check Jenkins service status
sudo systemctl status jenkins

# Check system logs
sudo journalctl -u jenkins -n 100 --no-pager

# Docker: check container logs
docker logs jenkins --tail 100

# Kubernetes: check pod logs
kubectl logs -n jenkins deployment/jenkins --tail 100

# Check for port conflicts
ss -tlnp | grep 8080
lsof -i :8080

# Check disk space (Jenkins needs space for logs, workspaces)
df -h /var/jenkins_home

# Check file permissions
ls -la /var/jenkins_home
# Jenkins user must own this directory
```

### Common Causes and Fixes

| Cause | Error Message | Fix |
|-------|---------------|-----|
| Wrong Java version | `UnsupportedClassVersionError` | Install Java 17 or 21 |
| Port conflict | `Address already in use: 8080` | `JENKINS_PORT=8081` or kill conflicting process |
| Disk full | `No space left on device` | Clean workspace, increase disk |
| Bad plugin | `Failed to load` in logs | Remove plugin from `plugins/` dir |
| Corrupted JENKINS_HOME | Various | Restore from backup |
| Insufficient memory | `OutOfMemoryError` | Increase `-Xmx` JVM arg |

```bash
# Fix: Remove corrupted plugin
# Jenkins stopped loading due to bad plugin
ls /var/jenkins_home/plugins/
rm /var/jenkins_home/plugins/bad-plugin.jpi
rm /var/jenkins_home/plugins/bad-plugin.jpi.pinned
sudo systemctl restart jenkins

# Fix: Safe mode (disables all plugins)
# Add to JENKINS_OPTS or JAVA_OPTS:
JAVA_OPTS="-Dhudson.Main.development=true -Dpermissive-script-security.enabled=true"
# Then start and remove the bad plugin via UI
```

---

## 2. Build Not Triggering

### Symptom
Code pushed to GitHub but Jenkins build doesn't start.

### Diagnosis

```bash
# Check webhook deliveries in GitHub
# GitHub → Repository → Settings → Webhooks → click your webhook → Recent Deliveries

# Test webhook manually
curl -v -X POST \
  https://jenkins.example.com/github-webhook/ \
  -H 'Content-Type: application/json' \
  -H 'X-GitHub-Event: push' \
  -d '{"ref":"refs/heads/main"}'

# Check Jenkins system log for webhook receipt
# Manage Jenkins → System Log → All Jenkins Logs
# Search for: "Received POST for..."

# Check if Jenkins URL is correct
# Manage Jenkins → System → Jenkins URL
# This must be publicly accessible from GitHub

# Check CSRF settings
# Manage Jenkins → Security → CSRF Protection
# Enable: Exclude X-Forwarded-For from proxies

# Check if job is configured for GitHub triggers
# Job → Configure → Build Triggers
# ✅ GitHub hook trigger for GITScm polling
```

### Polling as Fallback

```groovy
// If webhooks can't work (firewall, air-gap)
triggers {
    pollSCM('H/5 * * * *')   // Poll every 5 minutes
}
```

### Webhook Troubleshooting Checklist

```
[ ] Jenkins URL is publicly accessible (not localhost)
[ ] Firewall allows inbound on port 443 (or 80)
[ ] GitHub webhook payload URL is correct
[ ] GitHub webhook secret matches Jenkins configuration
[ ] CSRF proxy header is excluded (if behind load balancer)
[ ] Job has "GitHub hook trigger for GITScm polling" enabled
[ ] GitHub webhook shows successful 200 responses
[ ] Jenkins system log shows webhook receipt
```

---

## 3. Agent Connection Problems

### Symptom
Agent shows offline, or builds are stuck in queue waiting for agents.

### SSH Agent

```bash
# Test SSH connectivity from controller to agent
ssh -v -i /var/jenkins_home/.ssh/agent_key jenkins@agent-host.example.com

# Check agent is running
ps aux | grep jenkins

# Check agent log
tail -f /var/jenkins/agent.log

# Check Java on agent
java -version

# Verify known_hosts entry
cat ~/.ssh/known_hosts | grep agent-host

# Test with verbose logging on controller
# Manage Jenkins → Nodes → agent-name → Log
```

### JNLP Agent

```bash
# Agent connects to controller (useful for agents behind firewalls)
# Check controller port 50000 is accessible
nc -zv jenkins.example.com 50000

# Check agent command
java -jar agent.jar \
  -url http://jenkins.example.com \
  -secret <secret-from-controller> \
  -name my-agent \
  -workDir /var/jenkins/agent

# Get secret from: Jenkins → Nodes → agent → (Run from agent command line)
```

### Kubernetes Agent

```bash
# Check if pods are being created
kubectl get pods -n jenkins -w

# Check pod events
kubectl describe pod <agent-pod> -n jenkins

# Check Jenkins Kubernetes plugin logs
# Manage Jenkins → System Log → org.csanchez.jenkins.plugins.kubernetes

# Common issues:
# Image pull error:
kubectl describe pod <pod> -n jenkins | grep -A 5 "Events:"

# Fix: ensure imagePullSecrets are configured
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass \
  -n jenkins

# Insufficient resources:
kubectl describe node | grep -A 5 "Allocated resources"

# RBAC issues:
kubectl auth can-i create pods --as=system:serviceaccount:jenkins:jenkins -n jenkins
```

---

## 4. Out of Memory (OOM) Errors

### Symptom
Jenkins crashes with `java.lang.OutOfMemoryError: Java heap space`

### Diagnosis

```bash
# Check current JVM memory settings
ps aux | grep jenkins | grep -o '\-Xmx[^ ]*'

# Check heap usage (Prometheus)
# jvm_memory_bytes_used{area="heap"} / jvm_memory_bytes_max{area="heap"}

# Check JVM GC logs
grep -i "OutOfMemory\|GC overhead\|heap space" /var/jenkins_home/logs/jenkins.log

# Thread dump on running instance
curl -s http://jenkins.example.com/threadDump --user admin:TOKEN > thread-dump.txt
```

### Fixes

```bash
# 1. Increase heap size
# Edit /etc/default/jenkins or Docker env
JAVA_OPTS="-Xmx4g -Xms1g -XX:+UseG1GC"

# 2. Configure G1GC for large heaps
JAVA_OPTS="-Xmx4g -Xms1g \
  -XX:+UseG1GC \
  -XX:G1HeapRegionSize=16m \
  -XX:MaxGCPauseMillis=200 \
  -XX:+ParallelRefProcEnabled \
  -XX:+UseStringDeduplication"

# 3. Reduce build history (main cause of memory growth)
# Manage Jenkins → Configure System → Build History Retention:
# Keep builds for: 30 days
# Keep max: 20 builds

# 4. Enable workspace cleanup to free disk and memory pressure
# Add to each pipeline:
post { always { cleanWs() } }

# 5. Reduce fingerprint database
# Manage Jenkins → Manage Old Data → Fingerprints
```

---

## 5. Pipeline Failures

### Syntax Errors

```
Error: java.io.IOException: Expected one of "agent" "post" "stages"...
```

```bash
# Validate Jenkinsfile before committing
curl -X POST \
  http://jenkins.example.com/pipeline-model-converter/validate \
  --user admin:TOKEN \
  -F "jenkinsfile=<Jenkinsfile"

# Use Jenkins Replay feature
# Build → Replay → modify and test without committing
```

### sh Step Failures

```bash
# Get full error output
sh '''
    set -euo pipefail    # Always add this
    set -x               # Print each command (debugging)
    your-command
'''

# Check exit code
def exitCode = sh(
    script: 'your-command',
    returnStatus: true
)
if (exitCode != 0) {
    error "Command failed with exit code: ${exitCode}"
}

# Capture output for debugging
def output = sh(
    script: 'your-command',
    returnStdout: true
).trim()
echo "Output: ${output}"
```

### Timeout Errors

```groovy
// Error: org.jenkinsci.plugins.workflow.steps.FlowInterruptedException: Timeout has been exceeded

// Fix 1: Increase timeout
options {
    timeout(time: 60, unit: 'MINUTES')  // Increase from 30
}

// Fix 2: Per-stage timeout
stage('Long-running Tests') {
    options {
        timeout(time: 45, unit: 'MINUTES')
    }
    steps {
        sh 'mvn test -Pintegration'
    }
}

// Fix 3: Make timeout configurable
parameters {
    string(name: 'BUILD_TIMEOUT', defaultValue: '30', description: 'Build timeout in minutes')
}
options {
    timeout(time: params.BUILD_TIMEOUT.toInteger(), unit: 'MINUTES')
}
```

### Stash/Unstash Failures

```groovy
// Error: java.io.IOException: Unable to use stash because...
// Cause: Stash exists but agent doesn't have access to it

// Fix: Verify stash was created
stage('Build') {
    steps {
        sh 'mvn package'
        stash name: 'artifacts', includes: 'target/*.jar'
        echo "Stash created: ${stash.getStash('artifacts')}"
    }
}

// Fix: Use archiveArtifacts instead of stash for large files
archiveArtifacts artifacts: 'target/*.jar', fingerprint: true

// Fix: Use the same agent for stages sharing data
pipeline {
    agent { label 'linux' }  // Global agent — all stages share workspace
    stages {
        stage('Build') { steps { sh 'mvn package' } }
        stage('Test')  { steps { sh 'mvn test' } }    // Can use build output
    }
}
```

### Credential Not Found

```bash
# Error: CredentialNotFoundException: No credentials found with id 'my-creds'

# Diagnosis:
# 1. Verify credential exists
# Manage Jenkins → Credentials → (system) → Global credentials
# Look for credential with ID: my-creds

# 2. Check scope — Global vs. Folder
# If credential is folder-scoped, it's not visible outside the folder

# 3. Check credential type matches usage
# Using: credentials('my-creds') in environment block
# Credential type: Secret text ← must match

# 4. Verify from pipeline context
steps {
    script {
        def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
            com.cloudbees.plugins.credentials.common.StandardCredentials,
            Jenkins.instance, null, null
        )
        creds.each { c ->
            echo "Found credential: ${c.id} (${c.class.simpleName})"
        }
    }
}
```

---

## 6. Docker-in-Docker Issues

### Permission Denied

```bash
# Error: Got permission denied while trying to connect to the Docker daemon socket
# Permission denied: /var/run/docker.sock

# Fix 1: Add Jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Fix 2: Change socket permissions (less secure)
sudo chmod 666 /var/run/docker.sock

# Fix 3: Run Jenkins container with docker group
docker run \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  jenkins/jenkins:lts
```

### Image Pull Rate Limits

```bash
# Error: toomanyrequests: You have reached your pull rate limit

# Fix 1: Authenticate with Docker Hub
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-credentials',
    usernameVariable: 'DH_USER',
    passwordVariable: 'DH_PASS'
)]) {
    sh "echo '${DH_PASS}' | docker login -u '${DH_USER}' --password-stdin"
}

# Fix 2: Mirror images to private registry
# Pull once → push to your registry → use your registry in Dockerfiles

# Fix 3: Configure registry mirror
# /etc/docker/daemon.json:
{
    "registry-mirrors": ["https://mirror.gcr.io"]
}
```

---

## 7. Git/SCM Issues

### Authentication Failures

```bash
# Error: Authentication failed
# Error: Permission denied (publickey)

# Test SSH key
ssh -v -i /path/to/key git@github.com

# Test HTTPS
git ls-remote https://github.com/org/repo.git

# Add credential to Jenkins:
# Manage Jenkins → Credentials → Add
# For SSH: SSH Username with private key
# For HTTPS: Username with password (use PAT, not password)

# Common: Expired personal access token
# GitHub → Settings → Developer settings → Personal access tokens → Regenerate
```

### Large Repository Checkout

```bash
# Issue: Checkout takes too long for large repos

# Fix 1: Shallow clone
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/main']],
    extensions: [
        [$class: 'CloneOption', depth: 1, noTags: true, shallow: true]
    ],
    userRemoteConfigs: [[url: 'https://github.com/org/repo.git']]
])

# Fix 2: Sparse checkout (only specific directories)
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/main']],
    extensions: [
        [$class: 'SparseCheckoutPaths', sparseCheckoutPaths: [
            [$class: 'SparseCheckoutPath', path: 'src/'],
            [$class: 'SparseCheckoutPath', path: 'tests/']
        ]]
    ],
    userRemoteConfigs: [[url: 'https://github.com/org/repo.git']]
])
```

---

## 8. Disk Space Issues

### Diagnosis

```bash
# Check overall disk usage
df -h /var/jenkins_home

# Find largest directories
du -sh /var/jenkins_home/*/ | sort -hr | head -20

# Find large files
find /var/jenkins_home -size +100M -type f | sort -k5nr

# Workspace is usually the biggest consumer
du -sh /var/jenkins_home/workspace/*/

# Build logs are next
du -sh /var/jenkins_home/jobs/*/builds/
```

### Cleanup

```bash
# Delete old workspaces
find /var/jenkins_home/workspace -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# Delete old build logs (keep last 20 per job)
# Do this via UI: Job → Build History → Delete old builds
# Or via API:
for job in $(curl -s http://jenkins.example.com/api/json?tree=jobs[name] \
    --user admin:TOKEN | jq -r '.jobs[].name'); do
    echo "Cleaning: $job"
    # Keep last 20 builds, delete rest
    curl -X DELETE http://jenkins.example.com/job/${job}/lastSuccessfulBuild/artifact/ \
        --user admin:TOKEN
done

# Delete Docker images on agents
docker image prune -af

# Remove unused Docker volumes
docker volume prune -f
```

### Preventive Configuration

```groovy
// Add to every pipeline
options {
    buildDiscarder(logRotator(
        numToKeepStr: '10',
        daysToKeepStr: '30',
        artifactNumToKeepStr: '3',
        artifactDaysToKeepStr: '7'
    ))
}

post {
    always {
        cleanWs()
    }
}
```

---

## 9. Plugin Conflicts

### Symptom
Jenkins behaves unexpectedly after plugin update, or fails to start.

### Diagnosis

```bash
# Check which plugins were recently updated
# Manage Jenkins → Plugin Manager → Installed → Sort by "Updated"

# Check Jenkins system log for plugin errors
# Manage Jenkins → System Log → All Jenkins Logs
grep -i "plugin\|Failed to load\|ClassLoader" /var/jenkins_home/logs/jenkins.log

# Safe mode: start Jenkins with all plugins disabled
# Add to JAVA_OPTS:
-Dhudson.Main.development=true
```

### Rolling Back a Plugin

```bash
# Option 1: Via UI
# Manage Jenkins → Plugin Manager → Installed → Downgrade (if available)

# Option 2: Manual rollback
# Download previous version from https://updates.jenkins.io/download/plugins/
cd /var/jenkins_home/plugins/
ls -la plugin-name*
# Remove current .jpi
rm plugin-name.jpi plugin-name.jpi.pinned 2>/dev/null
# Copy old version
cp /backups/plugins/plugin-name-1.2.3.jpi plugin-name.jpi
# Restart Jenkins
sudo systemctl restart jenkins

# Option 3: Restore from backup
# Restore plugins/ directory from last known good backup
```

---

## 10. Performance Debugging

### Identify Slow Builds

```bash
# Jenkins API: find slowest recent builds
curl -s "http://jenkins.example.com/api/json?tree=jobs[name,builds[number,duration,result]]" \
  --user admin:TOKEN | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for job in data['jobs']:
    if job.get('builds'):
        avg_duration = sum(b.get('duration', 0) for b in job['builds']) / len(job['builds']) / 1000
        print(f\"{job['name']}: {avg_duration:.1f}s avg\")
" | sort -t: -k2 -rn | head -20
```

### Thread Dump Analysis

```bash
# Get thread dump from running Jenkins
curl -s http://jenkins.example.com/threadDump --user admin:TOKEN > thread-dump.txt

# Analyze for deadlocks
grep -A 5 "BLOCKED\|deadlock" thread-dump.txt

# Count threads by state
grep "java.lang.Thread.State:" thread-dump.txt | sort | uniq -c | sort -rn
```

### Build Log Analysis

```bash
# Find common error patterns across builds
for logfile in /var/jenkins_home/jobs/*/builds/*/log; do
    grep -l "ERROR\|FAILED\|Exception" "$logfile"
done | \
xargs grep -h "ERROR\|FAILED\|Exception" | \
sort | uniq -c | sort -rn | head -20
```

---

## 11. Useful Debugging Commands

```bash
# Jenkins CLI commands
# Download Jenkins CLI
curl -s http://jenkins.example.com/jnlpJars/jenkins-cli.jar -o jenkins-cli.jar

# List all jobs
java -jar jenkins-cli.jar -s http://jenkins.example.com -auth admin:TOKEN list-jobs

# Get job config
java -jar jenkins-cli.jar -s http://jenkins.example.com -auth admin:TOKEN get-job my-job

# Trigger build
java -jar jenkins-cli.jar -s http://jenkins.example.com -auth admin:TOKEN build my-job -p KEY=VALUE

# Get build console output
java -jar jenkins-cli.jar -s http://jenkins.example.com -auth admin:TOKEN console my-job 42

# Restart Jenkins (safe — waits for builds to finish)
java -jar jenkins-cli.jar -s http://jenkins.example.com -auth admin:TOKEN safe-restart

# Reload configuration
java -jar jenkins-cli.jar -s http://jenkins.example.com -auth admin:TOKEN reload-configuration
```

```groovy
// Useful Pipeline debugging snippets

// Print all environment variables (WARNING: may expose secrets)
sh 'env | grep -v "PASSWORD\|TOKEN\|SECRET\|KEY" | sort'

// Print current directory contents
sh 'pwd && ls -la'

// Print git status
sh 'git log --oneline -5 && git status'

// Check disk space on agent
sh 'df -h . && du -sh * | sort -hr | head -10'

// Print Java/Maven/Node versions
sh 'java -version && mvn -version || node -v && npm -v'

// Test network connectivity from agent
sh 'curl -sv https://github.com 2>&1 | head -20'
```

---

## Troubleshooting Quick Reference

| Symptom | First Check | Common Fix |
|---------|-------------|------------|
| Jenkins won't start | Java version, port conflict | Install Java 17/21, change port |
| Build not triggering | Webhook delivery, Jenkins URL | Fix webhook URL, enable CSRF exclusion |
| Agent offline | Network, SSH key, Java on agent | Fix connectivity, update key |
| OOM error | Heap settings, build history | Increase -Xmx, add buildDiscarder |
| Disk full | Workspaces, build logs | Add cleanWs(), buildDiscarder |
| Plugin conflict | Recent updates, system log | Downgrade plugin |
| Slow builds | Stage timing, parallel opportunities | Add parallel stages, optimize |
| Credential not found | Credential ID, scope | Fix ID or change scope to Global |
| Docker permission denied | Socket permissions, group | Add Jenkins to docker group |
| Git auth failure | Credential type, token expiry | Regenerate PAT, use SSH key |

---

## References

- [Jenkins Troubleshooting Guide](https://www.jenkins.io/doc/book/troubleshooting/)
- [Jenkins System Log](https://www.jenkins.io/doc/book/system-administration/diagnosing-errors/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [Docker Troubleshooting](https://docs.docker.com/config/daemon/troubleshoot/)
- [Jenkins Community Forum](https://community.jenkins.io/)
- [Jenkins JIRA](https://issues.jenkins.io/)

---

## Next Section

[15 — Real-World Projects →](../15-real-world-projects/README.md)
