# 11 — Production-Grade Jenkins

## Overview

Running Jenkins in production requires far more than a basic installation. This section covers high availability, backup and recovery, performance tuning, Configuration as Code, scaling strategies, and operational best practices used in enterprise environments.

---

## Topics Covered

1. Jenkins Configuration as Code (JCasC)
2. High Availability (HA) Setup
3. Backup and Disaster Recovery
4. Performance Tuning
5. Plugin Management at Scale
6. Distributed Builds
7. Blue-Green Jenkins Upgrades
8. Operational Runbooks

---

## 1. Jenkins Configuration as Code (JCasC)

JCasC allows you to configure all Jenkins settings via YAML files — eliminating manual click-ops and making Jenkins configuration reproducible, version-controlled, and auditable.

### Install JCasC Plugin

```bash
# Via plugins.txt
configuration-as-code:1800.v28740ed978fb_
```

### Complete JCasC Configuration

```yaml
# jenkins.yaml
jenkins:
  systemMessage: |
    🚀 Jenkins Production Instance
    Managed via Configuration as Code — do not modify via UI.
    All changes must go through the jenkins-config repository.

  numExecutors: 0  # Never build on controller
  mode: EXCLUSIVE
  scmCheckoutRetryCount: 3
  quietPeriod: 0

  # Global node properties
  globalNodeProperties:
  - envVars:
      env:
      - key: DOCKER_REGISTRY
        value: registry.example.com
      - key: DEFAULT_AGENT_LABEL
        value: linux

  # Security configuration
  authorizationStrategy:
    roleBased:
      roles:
        global:
        - name: admin
          pattern: ".*"
          permissions:
          - "Overall/Administer"
          assignments:
          - "jenkins-admins"
        - name: developer
          pattern: ".*"
          permissions:
          - "Overall/Read"
          - "Job/Build"
          - "Job/Read"
          - "Job/Workspace"
          - "View/Read"
          assignments:
          - "jenkins-developers"
        - name: viewer
          pattern: ".*"
          permissions:
          - "Overall/Read"
          - "Job/Read"
          - "View/Read"
          assignments:
          - "jenkins-viewers"

  securityRealm:
    ldap:
      configurations:
      - server: ldap://ldap.example.com
        rootDN: dc=example,dc=com
        userSearchBase: ou=users
        userSearch: uid={0}
        groupSearchBase: ou=groups
        groupSearchFilter: (member={0})
        inhibitInferRootDN: false
      disableMailAddressResolver: false

  # Cloud configuration
  clouds:
  - kubernetes:
      name: "kubernetes"
      namespace: "jenkins"
      jenkinsUrl: "http://jenkins:8080"
      jenkinsTunnel: "jenkins-agent:50000"
      containerCapStr: "20"
      templates:
      - name: "maven"
        label: "maven linux"
        serviceAccount: "jenkins"
        containers:
        - name: "jnlp"
          image: "jenkins/inbound-agent:latest-jdk21"
          resourceRequestCpu: "100m"
          resourceRequestMemory: "256Mi"
          resourceLimitCpu: "500m"
          resourceLimitMemory: "512Mi"
        - name: "maven"
          image: "maven:3.9-eclipse-temurin-21"
          command: "sleep"
          args: "99d"
          tty: true
          resourceRequestCpu: "500m"
          resourceRequestMemory: "1Gi"
          resourceLimitCpu: "2000m"
          resourceLimitMemory: "4Gi"

tool:
  git:
    installations:
    - name: Default
      home: /usr/bin/git
  maven:
    installations:
    - name: Maven-3.9
      properties:
      - installSource:
          installers:
          - maven:
              id: "3.9.6"
  jdk:
    installations:
    - name: JDK-21
      properties:
      - installSource:
          installers:
          - adoptOpenJdkInstaller:
              id: "jdk-21+35"

unclassified:
  location:
    url: https://jenkins.example.com
    adminAddress: jenkins@example.com

  # Slack configuration
  slackNotifier:
    teamDomain: mycompany
    tokenCredentialId: slack-token
    botUser: true

  # GitHub configuration
  githubPluginConfig:
    configs:
    - credentialsId: github-credentials
      name: GitHub
      apiUrl: https://api.github.com

  # SonarQube configuration
  sonarGlobalConfiguration:
    buildWrapperEnabled: false
    installations:
    - name: sonarqube
      serverUrl: https://sonarqube.example.com
      credentialsId: sonar-token

  # Global pipeline settings
  globalDefaultFlowDurabilityLevel:
    durabilityHint: PERFORMANCE_OPTIMIZED

  timestamper:
    allPipelines: true
    systemTimeFormat: "'<b>'HH:mm:ss'</b> '"
    elapsedTimeFormat: "'<b>'HH:mm:ss.S'</b> '"

credentials:
  system:
    domainCredentials:
    - credentials:
      - usernamePassword:
          scope: GLOBAL
          id: github-credentials
          description: GitHub Bot Token
          username: jenkins-bot
          password: ${GITHUB_TOKEN}
      - string:
          scope: GLOBAL
          id: slack-token
          description: Slack Bot Token
          secret: ${SLACK_TOKEN}
      - string:
          scope: GLOBAL
          id: sonar-token
          description: SonarQube Authentication Token
          secret: ${SONAR_TOKEN}
```

### Apply JCasC Configuration

```bash
# Environment variables for secrets
export GITHUB_TOKEN="ghp_yourtoken"
export SLACK_TOKEN="xoxb-yourtoken"
export SONAR_TOKEN="sqa_yourtoken"

# Via Helm (recommended)
helm upgrade jenkins jenkinsci/jenkins \
  --set controller.JCasC.configScripts.main="$(cat jenkins.yaml)"

# Via Docker
docker run -d \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs \
  -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
  -v $(pwd)/casc_configs:/var/jenkins_home/casc_configs \
  jenkins/jenkins:lts

# Reload configuration (without restart)
curl -X POST http://jenkins.example.com/reload-configuration-as-code/ \
  --user admin:TOKEN
```

---

## 2. High Availability Setup

Jenkins HA is complex because Jenkins state is stored on disk (JENKINS_HOME). The common approaches:

### Option A: Active-Passive with Shared Storage

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Load Balancer (Routes all traffic to Active instance)          │
│       │                                                         │
│  ┌────▼────┐                    ┌───────────┐                   │
│  │ Jenkins │                    │  Jenkins  │                   │
│  │ Active  │                    │  Standby  │                   │
│  │  Pod 1  │                    │   Pod 2   │                   │
│  └────┬────┘                    └─────┬─────┘                   │
│       │                               │                         │
│       └───────────┬───────────────────┘                         │
│                   │                                             │
│           ┌───────▼────────┐                                    │
│           │  Shared NFS /  │                                    │
│           │  EFS / Ceph    │                                    │
│           │  (JENKINS_HOME)│                                    │
│           └────────────────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

```yaml
# Kubernetes StatefulSet for Active-Passive
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1  # Start with 1; failover by scaling to 1 again
  selector:
    matchLabels:
      app: jenkins
  serviceName: jenkins
  template:
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts-jdk21
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 4000m
            memory: 8Gi
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
  volumeClaimTemplates:
  - metadata:
      name: jenkins-home
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "ssd"
      resources:
        requests:
          storage: 100Gi
```

### Option B: CloudBees CI (Enterprise HA)

CloudBees CI provides true active-active HA for Jenkins. Recommended for:
- Large organizations (> 500 developers)
- > 1,000 builds per day
- Multi-region deployments
- Strict SLA requirements

### Option C: Operations Center + Controllers (Recommended for Scale)

```
┌─────────────────────────────────────────────────────────────────┐
│                     OPERATIONS CENTER                            │
│  (Manages multiple Jenkins controllers)                         │
│                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│  │ Controller │  │ Controller │  │ Controller │                │
│  │ Team Alpha │  │ Team Beta  │  │ Platform   │                │
│  └────────────┘  └────────────┘  └────────────┘                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Shared Agent Pool                        │ │
│  │  (Kubernetes dynamic agents shared across controllers)      │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Backup and Disaster Recovery

### Automated Backup with ThinBackup Plugin

```groovy
// Configure via JCasC
unclassified:
  thinBackup:
    backupPath: /backups/jenkins
    fullBackupSchedule: "H 2 * * 0"     # Weekly full backup (Sunday 2 AM)
    diffBackupSchedule: "H 2 * * 1-6"   # Daily diff backup (Mon-Sat 2 AM)
    nrMaxStoredFull: 4                   # Keep 4 full backups
    cleanUpDiff: true
    moveOldBackupsToZipFile: true
    backupBuildResults: false            # Build results can be huge
    backupBuildArchive: false
    backupUserContents: true
    backupPlugins: true
    backupAdditionalFiles: true
```

### Backup Script (External)

```bash
#!/bin/bash
# scripts/backup-jenkins.sh
set -euo pipefail

JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
S3_BUCKET="${S3_BUCKET:-s3://my-jenkins-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="jenkins-backup-${TIMESTAMP}"

echo "Starting Jenkins backup: ${BACKUP_NAME}"

# Create local archive
mkdir -p "${BACKUP_DIR}"
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    --exclude="${JENKINS_HOME}/workspace" \
    --exclude="${JENKINS_HOME}/builds" \
    --exclude="${JENKINS_HOME}/logs" \
    --exclude="${JENKINS_HOME}/caches" \
    "${JENKINS_HOME}"

echo "Archive created: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "Size: $(du -sh ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz | cut -f1)"

# Upload to S3
aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    "${S3_BUCKET}/${BACKUP_NAME}.tar.gz" \
    --storage-class STANDARD_IA

echo "Uploaded to: ${S3_BUCKET}/${BACKUP_NAME}.tar.gz"

# Clean up local backups older than 7 days
find "${BACKUP_DIR}" -name "jenkins-backup-*.tar.gz" -mtime +7 -delete

echo "Backup complete: ${BACKUP_NAME}"
```

### Velero Backup (Kubernetes)

```bash
# Install Velero
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.8.0 \
    --bucket jenkins-velero-backups \
    --backup-location-config region=us-east-1 \
    --snapshot-location-config region=us-east-1 \
    --secret-file ./credentials-velero

# Create scheduled backup
velero schedule create jenkins-daily \
    --schedule="0 2 * * *" \
    --include-namespaces jenkins \
    --ttl 168h0m0s   # 7 days

# Manual backup
velero backup create jenkins-manual-$(date +%Y%m%d) \
    --include-namespaces jenkins

# Restore
velero restore create --from-backup jenkins-daily-20260507020000
```

---

## 4. Performance Tuning

### JVM Tuning

```bash
# /etc/default/jenkins (or Docker ENV)
JAVA_OPTS="\
  -server \
  -Xmx4g \
  -Xms1g \
  -XX:+UseG1GC \
  -XX:G1HeapRegionSize=16m \
  -XX:+UseStringDeduplication \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 \
  -Dsun.net.inetaddr.ttl=60 \
  -Djava.awt.headless=true \
  -Djenkins.model.Jenkins.logRecorders.maxSize=1000 \
"
```

### Jenkins System Properties

```properties
# System properties (set via JAVA_OPTS or jenkins.properties)
# Pipeline execution
jenkins.pipeline.durability.globalDefaultFlowDurabilityLevel=PERFORMANCE_OPTIMIZED

# Build queue
hudson.model.Queue.maxRetries=50
hudson.model.Queue.retryDelay=5000

# Fingerprints
hudson.model.FingerprintCleanupThread.disabled=true

# Disable statistics
jenkins.model.Jenkins.disabledAdministrativeMonitors=\
  hudson.diagnosis.TooManyJobsButNoBuildsAdministrativeMonitor

# Agent timeout
org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud.defaultReadTimeout=60
org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud.defaultConnectTimeout=60
```

### Workspace Cleanup

```groovy
// Global pipeline settings via JCasC
unclassified:
  globalDefaultFlowDurabilityLevel:
    durabilityHint: PERFORMANCE_OPTIMIZED

// In pipelines
options {
    // Auto-delete old workspaces
    durabilityHint('PERFORMANCE_OPTIMIZED')
    buildDiscarder(logRotator(
        numToKeepStr: '10',
        artifactNumToKeepStr: '5'
    ))
}

post {
    always {
        cleanWs(
            cleanWhenAborted: true,
            cleanWhenFailure: true,
            cleanWhenNotBuilt: false,
            cleanWhenSuccess: true,
            cleanWhenUnstable: true,
            deleteDirs: true
        )
    }
}
```

---

## 5. Plugin Management at Scale

### Pinned Plugin Versions (plugins.txt)

```properties
# plugins.txt — Always pin specific versions
git:5.2.1
pipeline-stage-view:2.34
blueocean:1.27.9
kubernetes:4.6.0
docker-workflow:563.vd5d2e5c4007f
configuration-as-code:1800.v28740ed978fb_
role-strategy:700.v72ea_42c7c04d
ansicolor:1.0.3
timestamper:1.27
build-timeout:1.32
ws-cleanup:0.46
junit:1240.vf9529b_a_cf_87a_
sonar:2.15
slack:2.50
email-ext:2.105
prometheus:2.5.1
job-dsl:1.87
lockable-resources:1175.v7db_e6d6b_a_e22
```

### Plugin Update Strategy

```bash
# Check for updates (safe to run in production)
java -jar jenkins-cli.jar \
  -s http://jenkins.example.com \
  -auth admin:TOKEN \
  list-plugins | grep -v " "

# Update a specific plugin (requires restart)
java -jar jenkins-cli.jar \
  -s http://jenkins.example.com \
  -auth admin:TOKEN \
  install-plugin git --restart

# Safe restart (waits for builds to complete)
java -jar jenkins-cli.jar \
  -s http://jenkins.example.com \
  -auth admin:TOKEN \
  safe-restart
```

---

## 6. Blue-Green Jenkins Upgrades

Upgrading Jenkins safely in production:

```bash
# Step 1: Backup current instance
./scripts/backup-jenkins.sh

# Step 2: Deploy new version alongside current (blue-green)
helm upgrade jenkins jenkinsci/jenkins \
  --set controller.tag=2.440.3-lts-jdk21 \
  --dry-run  # Test first

# Step 3: Quiesce current instance
# Manage Jenkins → Manage Nodes → Shut down Jenkins (when builds complete)

# Step 4: Apply upgrade
helm upgrade jenkins jenkinsci/jenkins \
  --set controller.tag=2.440.3-lts-jdk21 \
  --wait

# Step 5: Validate
curl -s http://jenkins.example.com/api/json?tree=version --user admin:TOKEN

# Step 6: Roll back if needed
helm rollback jenkins 1
```

---

## 7. Operational Runbook

### Daily Health Checks

```bash
#!/bin/bash
# scripts/jenkins-health-check.sh
set -euo pipefail

JENKINS_URL="https://jenkins.example.com"
JENKINS_USER="health-check-user"
JENKINS_TOKEN="${JENKINS_TOKEN}"

echo "=== Jenkins Health Check ==="

# 1. Check Jenkins is responding
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "${JENKINS_URL}/api/json" --user "${JENKINS_USER}:${JENKINS_TOKEN}")
if [ "${STATUS}" = "200" ]; then
    echo "✅ Jenkins API: OK"
else
    echo "❌ Jenkins API: ${STATUS}"
    exit 1
fi

# 2. Check agent availability
AGENTS=$(curl -s "${JENKINS_URL}/computer/api/json" \
    --user "${JENKINS_USER}:${JENKINS_TOKEN}" | \
    python3 -c "import sys,json; data=json.load(sys.stdin); 
    offline=[c['displayName'] for c in data['computer'] if c.get('offline', False)];
    print(f'Total: {len(data[\"computer\"])}, Offline: {len(offline)}'); 
    [print(f'  - {n}') for n in offline]")
echo "📊 Agents: ${AGENTS}"

# 3. Check queue length
QUEUE=$(curl -s "${JENKINS_URL}/queue/api/json" \
    --user "${JENKINS_USER}:${JENKINS_TOKEN}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['items']))")
echo "📋 Queue: ${QUEUE} items waiting"
if [ "${QUEUE}" -gt 50 ]; then
    echo "⚠️  WARNING: Queue length is ${QUEUE} — investigate"
fi

# 4. Check disk space
DISK=$(df -h "${JENKINS_HOME:-/var/jenkins_home}" | tail -1 | awk '{print $5}' | tr -d '%')
echo "💾 Disk: ${DISK}% used"
if [ "${DISK}" -gt 80 ]; then
    echo "⚠️  WARNING: Disk usage is ${DISK}%"
fi

echo "=== Health Check Complete ==="
```

---

## 8. Monitoring & Alerting Setup

```yaml
# prometheus-serviceMonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jenkins
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: jenkins
  namespaceSelector:
    matchNames:
    - jenkins
  endpoints:
  - port: http
    path: /prometheus
    interval: 30s
    scrapeTimeout: 10s
```

### Key Jenkins Metrics (Prometheus)

```
# Build queue
jenkins_queue_size_value

# Executor utilization
jenkins_executor_count_value - jenkins_executor_free_value

# Job duration (95th percentile)
histogram_quantile(0.95, rate(jenkins_builds_duration_milliseconds_bucket[5m]))

# Build failure rate
rate(jenkins_builds_failed_builds_total[5m]) /
rate(jenkins_builds_total_builds_total[5m])

# Agent availability
jenkins_node_count_value - jenkins_node_offline_value
```

### Grafana Dashboard

Import dashboard ID `9964` — "Jenkins: Performance and Health Overview"

---

## Best Practices Summary

| Practice | Description | Priority |
|----------|-------------|----------|
| JCasC | All config in code | Critical |
| Zero controller executors | Never build on controller | Critical |
| Automated backups | Daily backup to external storage | Critical |
| Plugin version pinning | Specific versions in plugins.txt | High |
| JVM tuning | Appropriate heap size and GC settings | High |
| Health monitoring | Prometheus + Grafana | High |
| HTTPS everywhere | TLS termination at ingress | High |
| Velero/ThinBackup | Scheduled automated backups | High |
| Build discarder | Limit build history | Medium |
| Audit logging | Track all changes | Medium |

---

## References

- [Jenkins Configuration as Code](https://www.jenkins.io/projects/jcasc/)
- [Jenkins Performance Tuning](https://www.jenkins.io/doc/book/scaling/)
- [CloudBees CI HA Guide](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha/)
- [ThinBackup Plugin](https://plugins.jenkins.io/thinBackup/)
- [Prometheus Metrics Plugin](https://plugins.jenkins.io/prometheus/)
- [Velero Backup](https://velero.io/docs/)

---

## Next Section

[12 — Security →](../12-security/README.md)
