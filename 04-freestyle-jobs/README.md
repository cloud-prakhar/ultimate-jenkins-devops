# 04 — Freestyle Jobs

## Overview

Freestyle Jobs are the simplest type of Jenkins job — configured entirely through the web UI. While modern DevOps favors Pipeline-as-Code, understanding Freestyle jobs is essential because millions of legacy Jenkins installations use them, and the concepts translate directly to Pipelines.

---

## Objectives

- Create and configure Freestyle jobs
- Understand all Freestyle job configuration options
- Integrate with Git source control
- Use build parameters for flexible builds
- Set up build triggers (webhooks, cron, upstream)
- Archive artifacts and publish test results
- Configure post-build notifications
- Understand limitations that drive Pipeline adoption

---

## Prerequisites

- Jenkins installed and running
- Git repository available
- Basic understanding of Jenkins UI (Section 03)

---

## What is a Freestyle Job?

A Freestyle job is a general-purpose, GUI-configured Jenkins job. You configure every aspect through forms in the web interface:

```
Source Code → Build Triggers → Build Environment → Build Steps → Post-Build Actions
```

### Freestyle vs Pipeline

| Feature | Freestyle | Pipeline |
|---------|-----------|----------|
| Configuration | Web UI | Jenkinsfile (code) |
| Version control | ❌ (manual export) | ✅ (committed with code) |
| Visualization | Limited | Stage view, Blue Ocean |
| Code reuse | ❌ | ✅ (shared libraries) |
| Parallel stages | ❌ | ✅ |
| Conditional logic | Limited | Full Groovy |
| Restart from stage | ❌ | ✅ |
| Production recommended | ❌ | ✅ |

> **When to use Freestyle:** Legacy systems, simple one-step builds, when no Jenkinsfile support exists in the codebase.

---

## Lab 1: Hello World Freestyle Job

### Create the Job

1. Navigate to **Dashboard → New Item**
2. Enter name: `01-hello-world`
3. Select: **Freestyle project**
4. Click **OK**

### Configure Build Steps

Under **Build Steps** → **Add build step** → **Execute shell**:

```bash
#!/bin/bash
set -euo pipefail

echo "========================================="
echo "  Jenkins Freestyle Job - Hello World    "
echo "========================================="
echo ""
echo "Build Information:"
echo "  Build Number:  ${BUILD_NUMBER}"
echo "  Build ID:      ${BUILD_ID}"
echo "  Job Name:      ${JOB_NAME}"
echo "  Workspace:     ${WORKSPACE}"
echo "  Jenkins URL:   ${JENKINS_URL}"
echo "  Node Name:     ${NODE_NAME}"
echo ""
echo "System Information:"
echo "  Hostname:      $(hostname)"
echo "  User:          $(whoami)"
echo "  Date:          $(date)"
echo "  OS:            $(uname -a)"
echo ""
echo "Build SUCCESS!"
```

5. Click **Save**
6. Click **Build Now**
7. Click on the build number → **Console Output**

---

## Lab 2: Git Integration Freestyle Job

### Create the Job

1. **New Item** → `02-git-integration` → **Freestyle project**

### Source Code Management

```
● Git
  Repository URL: https://github.com/your-org/your-repo.git
  Credentials: [Select your GitHub credentials]
  Branches to build: */main
  
  Additional Behaviours:
  + Wipe out repository & force clone
  + Check out to specific local branch: main
```

### Build Triggers

```
[x] Poll SCM
    Schedule: H/5 * * * *
```

> For production, use webhooks instead of polling. See Lab 4 for webhook setup.

### Build Steps

```bash
#!/bin/bash
set -euo pipefail

echo "=== Repository Information ==="
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git log -1 --oneline)"
echo "Author: $(git log -1 --format='%an <%ae>')"
echo ""
echo "=== Repository Contents ==="
ls -la
echo ""
echo "=== Recent Commits ==="
git log --oneline -5
```

---

## Lab 3: Parameterized Build

Parameters make builds flexible — the same job can build different branches, versions, or environments.

### Create the Job

1. **New Item** → `03-parameterized-build` → **Freestyle project**

### Configure Parameters

Under **General** → **[x] This project is parameterized**:

**Parameter 1: String**
```
Name: BRANCH
Default Value: main
Description: Git branch to build (e.g., main, develop, feature/my-feature)
```

**Parameter 2: Choice**
```
Name: ENVIRONMENT
Choices:
  dev
  staging
  production
Description: Target deployment environment
```

**Parameter 3: Boolean**
```
Name: SKIP_TESTS
Default Value: false
Description: Skip test execution (use only for hotfix deployments)
```

**Parameter 4: String**
```
Name: VERSION
Default Value: 1.0.${BUILD_NUMBER}
Description: Artifact version to produce
```

### Source Code Management

```
Git Repository URL: https://github.com/your-org/your-repo.git
Branch: */${BRANCH}
```

### Build Steps

```bash
#!/bin/bash
set -euo pipefail

echo "========================================="
echo "  Parameterized Build"
echo "========================================="
echo "Branch:      ${BRANCH}"
echo "Environment: ${ENVIRONMENT}"
echo "Version:     ${VERSION}"
echo "Skip Tests:  ${SKIP_TESTS}"
echo "Build:       #${BUILD_NUMBER}"
echo ""

# Build phase
echo "=== Building application ==="
# mvn clean package ${SKIP_TESTS:+-DskipTests}
echo "Build complete: version ${VERSION}"

# Conditional test execution
if [ "${SKIP_TESTS}" = "false" ]; then
    echo "=== Running tests ==="
    # mvn test
    echo "Tests passed"
else
    echo "=== Tests SKIPPED (as requested) ==="
fi

# Environment-specific deployment
echo "=== Deploying to ${ENVIRONMENT} ==="
case "${ENVIRONMENT}" in
  dev)
    echo "Deploying to dev cluster..."
    # kubectl apply -f k8s/dev/
    ;;
  staging)
    echo "Deploying to staging cluster..."
    # kubectl apply -f k8s/staging/
    ;;
  production)
    echo "Deploying to production cluster..."
    # kubectl apply -f k8s/production/
    ;;
esac

echo ""
echo "Deployment to ${ENVIRONMENT} complete!"
```

### Running with Parameters

- Click **Build with Parameters**
- Fill in parameter values
- Click **Build**

---

## Lab 4: Webhook Trigger (GitHub)

Webhooks trigger builds instantly on code push — far better than polling.

### Jenkins Setup

1. **Manage Jenkins → Security**
2. Note your Jenkins URL: `https://jenkins.example.com`
3. Ensure **GitHub hook trigger for GITScm polling** is enabled on the job

For token-based webhook:
1. In job **Configure** → **Build Triggers**
2. Enable **Trigger builds remotely (e.g., from scripts)**
3. Set Authentication Token: `MY-SECRET-TOKEN-RANDOM-STRING`
4. Webhook URL becomes: `https://jenkins.example.com/job/my-job/build?token=MY-SECRET-TOKEN-RANDOM-STRING`

### GitHub Setup

1. Navigate to your GitHub repository
2. **Settings → Webhooks → Add webhook**

```
Payload URL: https://jenkins.example.com/github-webhook/
Content type: application/json
Secret: (leave empty or set a shared secret)
Which events: Just the push event
Active: ✅
```

### GitLab Setup

```
Settings → Integrations → Jenkins CI
Jenkins URL: https://jenkins.example.com
Project name: your-job-name
Username: jenkins-webhook-user
Password: jenkins-api-token
```

---

## Lab 5: Maven Build with Test Reports

### Prerequisites

```bash
# Ensure Maven is installed on the agent
mvn -version

# Or configure under Manage Jenkins → Tools → Maven
```

### Create the Job

1. **New Item** → `05-maven-build` → **Freestyle project**

### Configure

**Source Code Management:**
```
Git URL: https://github.com/your-org/java-app.git
Branch: */main
```

**Build Steps** → **Invoke top-level Maven targets:**
```
Maven version: Maven-3.9
Goals: clean package
POM: pom.xml
Properties:
  MAVEN_OPTS=-Xmx1g
```

Or using Execute shell:

```bash
#!/bin/bash
set -euo pipefail

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

echo "Java version:"
java -version

echo "Maven version:"
mvn -version

echo "=== Building Java Application ==="
mvn clean package \
  -Dmaven.test.failure.ignore=true \
  -Dsurefire.reportFormat=xml \
  -B \
  --no-transfer-progress

echo "=== Build artifacts ==="
ls -la target/*.jar 2>/dev/null || ls -la target/*.war 2>/dev/null || echo "No JAR/WAR found"
```

**Post-build Actions:**

```
Publish JUnit test result report:
  Test report XMLs: target/surefire-reports/*.xml, target/failsafe-reports/*.xml
  [ ] Retain long standard output/error

Archive the artifacts:
  Files to archive: target/*.jar, target/*.war
  [ ] Fingerprint all archived artifacts
```

---

## Lab 6: Upstream/Downstream Jobs

Chain jobs together to create a simple pipeline.

### Create CI Job

1. **New Item** → `06-ci-build` → **Freestyle project**

**Build Steps:**
```bash
#!/bin/bash
set -euo pipefail
echo "Building application..."
# mvn clean package
echo "BUILD_VERSION=1.0.${BUILD_NUMBER}" > build.properties
cat build.properties
echo "Build complete"
```

**Post-build Actions:**
```
Archive the artifacts: build.properties

Trigger parameterized build on other projects:
  Projects to build: 06-cd-deploy
  Trigger when build is: Stable
  Parameters: (paste build artifacts from file)
    Properties file: build.properties
```

### Create CD Job

1. **New Item** → `06-cd-deploy` → **Freestyle project**

**General:**
```
[x] This project is parameterized
  String parameter: BUILD_VERSION
```

**Build Steps:**
```bash
#!/bin/bash
set -euo pipefail
echo "Deploying version: ${BUILD_VERSION}"
echo "Triggered by upstream build: ${BUILD_NUMBER}"
# Deploy commands here
echo "Deployment complete"
```

---

## Lab 7: Environment Variables

Jenkins provides many built-in environment variables.

### Built-in Variables

```bash
#!/bin/bash
echo "=== Jenkins Built-in Environment Variables ==="
echo ""
echo "Build Information:"
echo "  BUILD_NUMBER:     ${BUILD_NUMBER}"        # Sequential build number
echo "  BUILD_ID:         ${BUILD_ID}"            # Build timestamp ID
echo "  BUILD_DISPLAY_NAME: ${BUILD_DISPLAY_NAME}" # #42
echo "  BUILD_URL:        ${BUILD_URL}"           # Full URL to this build
echo "  BUILD_TAG:        ${BUILD_TAG}"           # jenkins-job-42

echo ""
echo "Job Information:"
echo "  JOB_NAME:         ${JOB_NAME}"            # my-app
echo "  JOB_BASE_NAME:    ${JOB_BASE_NAME}"       # my-app (without folder)
echo "  JOB_URL:          ${JOB_URL}"             # Full URL to the job

echo ""
echo "Workspace:"
echo "  WORKSPACE:        ${WORKSPACE}"           # /var/jenkins_home/workspace/my-app
echo "  WORKSPACE_TMP:    ${WORKSPACE_TMP}"       # Temp directory

echo ""
echo "SCM Information:"
echo "  GIT_COMMIT:       ${GIT_COMMIT}"          # Full commit SHA
echo "  GIT_BRANCH:       ${GIT_BRANCH}"          # origin/main
echo "  GIT_URL:          ${GIT_URL}"             # Repository URL

echo ""
echo "Node/Agent:"
echo "  NODE_NAME:        ${NODE_NAME}"           # Agent name
echo "  NODE_LABELS:      ${NODE_LABELS}"         # Agent labels
echo "  EXECUTOR_NUMBER:  ${EXECUTOR_NUMBER}"     # 0, 1, 2...

echo ""
echo "Jenkins:"
echo "  JENKINS_URL:      ${JENKINS_URL}"         # http://jenkins:8080/
echo "  JENKINS_HOME:     ${JENKINS_HOME}"        # /var/jenkins_home
```

### Setting Custom Environment Variables

In **Build Environment** → **Inject environment variables to the build process**:

```properties
APP_NAME=my-application
REGISTRY=registry.example.com
DEPLOY_NAMESPACE=production
```

---

## Freestyle Job Best Practices

### 1. Always Use set -euo pipefail

```bash
#!/bin/bash
set -euo pipefail
# -e: exit on error
# -u: treat unset variables as errors
# -o pipefail: propagate pipe failures
```

### 2. Set a Build Timeout

```
Build Environment:
[x] Abort the build if it's stuck
    Timeout: 30 minutes
    Type: Abort the Build
```

### 3. Clean Workspace

```
Build Environment:
[x] Delete workspace before build starts

Post-build Actions:
[x] Delete workspace when build is done
```

### 4. Limit Build History

```
General:
[x] Discard old builds
    Max # of builds to keep: 20
    Max # of days to keep: 30
```

### 5. Use Credentials Binding

```
Build Environment:
[x] Use secret text(s) or file(s)
  Secret text:
    Variable: DOCKER_TOKEN
    Credentials: dockerhub-token
  Username and password (separated):
    Username Variable: DB_USER
    Password Variable: DB_PASS
    Credentials: database-credentials
```

### 6. Archive Important Artifacts

```
Post-build Actions:
Archive the artifacts:
  target/*.jar
  target/surefire-reports/
  coverage-report/
```

---

## Migrating Freestyle Jobs to Pipelines

As jobs grow complex, migrate to Pipelines:

**Freestyle → Declarative Pipeline mapping:**

```groovy
// Freestyle: Source Code Management → Git
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/main']],
    userRemoteConfigs: [[
        url: 'https://github.com/org/repo.git',
        credentialsId: 'github-credentials'
    ]]
])

// Freestyle: Build Steps → Execute shell
sh '''
  mvn clean package
'''

// Freestyle: Post-build → Publish JUnit
junit 'target/surefire-reports/*.xml'

// Freestyle: Post-build → Archive artifacts
archiveArtifacts artifacts: 'target/*.jar', fingerprint: true

// Freestyle: Post-build → Email notification
emailext(
    to: 'team@example.com',
    subject: "Build ${currentBuild.result}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
    body: "${env.BUILD_URL}"
)
```

---

## Troubleshooting Freestyle Jobs

### Build Not Triggering

```
✅ Verify webhook URL is accessible from GitHub (test with curl)
✅ Check Jenkins system log for webhook receipt
✅ Verify GitHub webhook delivery (Settings → Webhooks → Recent Deliveries)
✅ Check CSRF settings if POST requests are rejected
✅ Verify the branch spec matches your branch (*/main vs origin/main)
```

### Git Authentication Failure

```bash
# Test SSH connectivity
ssh -T git@github.com

# Test HTTPS
git ls-remote https://github.com/org/repo.git

# Verify credential ID in Jenkins matches job configuration
# Manage Jenkins → Credentials → check credential exists
```

### Workspace Issues

```bash
# Clear workspace manually
rm -rf ${WORKSPACE}/*

# Or enable "Wipe out repository & force clone" in SCM settings
# Or enable "Delete workspace before build starts" in Build Environment
```

### Maven Build Failures

```bash
# Check Maven is in PATH
which mvn

# Check Java version compatibility
java -version

# Run with verbose output
mvn clean package -X 2>&1 | head -100

# Check for dependency issues
mvn dependency:resolve
```

---

## Security Considerations

1. **Never echo credentials** in build steps — they appear in console output
2. **Use credentials binding** — never hardcode in shell scripts
3. **Restrict parameterized inputs** — validate parameters in build scripts before use
4. **Limit job permissions** — use Project-based Matrix or Role-Based Strategy
5. **Audit webhook secrets** — rotate them periodically
6. **Disable concurrent builds** for jobs that modify shared state

---

## References

- [Jenkins Freestyle Jobs](https://www.jenkins.io/doc/book/using/jobs/)
- [Git Plugin](https://plugins.jenkins.io/git/)
- [JUnit Plugin](https://plugins.jenkins.io/junit/)
- [Credentials Binding Plugin](https://plugins.jenkins.io/credentials-binding/)
- [Parameterized Trigger Plugin](https://plugins.jenkins.io/parameterized-trigger/)
- [EnvInject Plugin](https://plugins.jenkins.io/envinject/)

---

## Next Section

[05 — Pipelines →](../05-pipelines/README.md)
