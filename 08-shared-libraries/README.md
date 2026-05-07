# 08 — Jenkins Shared Libraries

## Overview

Jenkins Shared Libraries are the cornerstone of enterprise-grade pipeline standardization. They allow you to define reusable pipeline logic once and use it across hundreds of pipelines — reducing duplication, enforcing standards, and enabling rapid onboarding of new services.

---

## Objectives

- Understand the Shared Library structure and loading mechanism
- Create a complete Shared Library from scratch
- Write `vars/` (global variables) and `src/` (Groovy classes)
- Version and distribute shared libraries
- Implement common enterprise patterns: build, test, deploy, notify
- Use dynamic loading and override mechanisms

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SHARED LIBRARY REPOSITORY                       │
│                                                                     │
│  jenkins-shared-library/                                            │
│  ├── vars/                   ← Global variables (pipeline steps)    │
│  │   ├── buildMavenApp.groovy                                       │
│  │   ├── buildDockerImage.groovy                                    │
│  │   ├── deployToKubernetes.groovy                                  │
│  │   └── sendNotification.groovy                                    │
│  ├── src/                    ← Groovy classes (OO logic)            │
│  │   └── org/example/
│  │       ├── DockerUtils.groovy                                     │
│  │       ├── KubernetesUtils.groovy                                 │
│  │       └── NotificationUtils.groovy                               │
│  ├── resources/              ← Static files (shell scripts, configs)│
│  │   ├── scripts/
│  │   │   └── deploy.sh
│  │   └── templates/
│  │       └── deployment.yaml
│  └── test/                   ← Unit tests for library               │
│      └── ...
└─────────────────────────────────────────────────────────────────────┘

Used in Pipelines across the organization:
  @Library('jenkins-shared-library@main') _
```

---

## Setting Up a Shared Library

### Step 1: Create the Repository

```bash
mkdir jenkins-shared-library
cd jenkins-shared-library
git init

# Create required directory structure
mkdir -p vars src/org/example resources/scripts resources/templates test

# Initialize as a Groovy project (optional but recommended)
touch build.gradle
```

### Step 2: Configure Jenkins to Use the Library

Navigate: **Manage Jenkins → System → Global Pipeline Libraries**

```
Name: jenkins-shared-library
Default version: main
Load implicitly: [ ] (leave unchecked — require explicit @Library)
Allow default version to be overridden: [x]
Include @Library changes in job recent changes: [x]

Source Code Management:
  Git:
    Project Repository: https://github.com/org/jenkins-shared-library.git
    Credentials: github-credentials
    Behaviors:
      Discover branches
```

### Step 3: Use in Pipelines

```groovy
// Load specific version
@Library('jenkins-shared-library@v2.1.0') _

// Load from branch
@Library('jenkins-shared-library@main') _

// Load multiple libraries
@Library(['jenkins-shared-library@main', 'security-library@v1.0']) _

// Implicit loading (if configured as implicit)
// No @Library annotation needed

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                buildMavenApp()  // Calls vars/buildMavenApp.groovy
            }
        }
    }
}
```

---

## `vars/` — Global Variables (Pipeline Steps)

Files in `vars/` become available as steps directly in pipelines.

### vars/buildMavenApp.groovy

```groovy
/**
 * Build a Maven-based Java application.
 *
 * @param config Map with options:
 *   - javaVersion: Java version (default: '21')
 *   - goals: Maven goals (default: 'clean package')
 *   - profiles: Maven profiles (default: '')
 *   - skipTests: Skip test execution (default: false)
 *   - extraArgs: Additional Maven arguments (default: '')
 *   - mavenOpts: MAVEN_OPTS value (default: '-Xmx1g')
 */
def call(Map config = [:]) {
    def defaults = [
        javaVersion : '21',
        goals       : 'clean package',
        profiles    : '',
        skipTests   : false,
        extraArgs   : '',
        mavenOpts   : '-Xmx1g -XX:+UseG1GC'
    ]
    config = defaults + config

    def profileArg = config.profiles ? "-P${config.profiles}" : ''
    def skipTestsArg = config.skipTests ? '-DskipTests' : ''

    withEnv(["MAVEN_OPTS=${config.mavenOpts}"]) {
        sh """
            mvn ${config.goals} \
              ${profileArg} \
              ${skipTestsArg} \
              ${config.extraArgs} \
              -B \
              --no-transfer-progress
        """
    }
}
```

**Usage:**
```groovy
// With defaults
buildMavenApp()

// With configuration
buildMavenApp(
    javaVersion: '21',
    goals: 'clean package',
    profiles: 'production',
    skipTests: false,
    extraArgs: '-Dmaven.repo.local=/cache/.m2'
)
```

### vars/buildDockerImage.groovy

```groovy
/**
 * Build and optionally push a Docker image.
 *
 * @param config Map with options:
 *   - imageName: Full image name (required)
 *   - imageTag: Image tag (default: BUILD_NUMBER-GIT_COMMIT[:7])
 *   - dockerfile: Path to Dockerfile (default: 'Dockerfile')
 *   - context: Build context (default: '.')
 *   - buildArgs: Map of build arguments (default: [:])
 *   - push: Push to registry (default: false)
 *   - registryCredId: Credential ID for registry (default: 'registry-credentials')
 *   - labels: Map of OCI labels (default: standard set)
 */
def call(Map config = [:]) {
    if (!config.imageName) {
        error "buildDockerImage: 'imageName' is required"
    }

    def defaults = [
        imageTag       : "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'unknown'}",
        dockerfile     : 'Dockerfile',
        context        : '.',
        buildArgs      : [:],
        push           : false,
        registryCredId : 'registry-credentials',
        labels         : [
            'org.opencontainers.image.source'  : env.GIT_URL ?: '',
            'org.opencontainers.image.revision': env.GIT_COMMIT ?: '',
            'org.opencontainers.image.created' : sh(script: 'date -u +%Y-%m-%dT%H:%M:%SZ', returnStdout: true).trim()
        ]
    ]
    config = defaults + config

    def fullImageName = "${config.imageName}:${config.imageTag}"

    // Build args flags
    def buildArgsFlags = config.buildArgs.collect { k, v -> "--build-arg ${k}=${v}" }.join(' ')

    // Labels flags
    def labelFlags = config.labels.collect { k, v -> "--label \"${k}=${v}\"" }.join(' ')

    sh """
        docker build \
          --file ${config.dockerfile} \
          ${buildArgsFlags} \
          ${labelFlags} \
          --tag ${fullImageName} \
          --tag ${config.imageName}:latest \
          ${config.context}
    """

    if (config.push) {
        withCredentials([usernamePassword(
            credentialsId: config.registryCredId,
            usernameVariable: 'REGISTRY_USER',
            passwordVariable: 'REGISTRY_PASS'
        )]) {
            def registry = config.imageName.split('/')[0]
            sh """
                echo '${REGISTRY_PASS}' | docker login ${registry} -u '${REGISTRY_USER}' --password-stdin
                docker push ${fullImageName}
                docker push ${config.imageName}:latest
                docker logout ${registry}
            """
        }
    }

    // Return the full image reference for use by downstream steps
    return fullImageName
}
```

**Usage:**
```groovy
def imageRef = buildDockerImage(
    imageName: 'registry.example.com/my-app',
    imageTag: "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}",
    buildArgs: [
        JAR_FILE: 'target/app.jar',
        BUILD_NUMBER: BUILD_NUMBER
    ],
    push: true,
    registryCredId: 'registry-credentials'
)
echo "Built and pushed: ${imageRef}"
```

### vars/deployToKubernetes.groovy

```groovy
/**
 * Deploy an application to Kubernetes using Helm.
 *
 * @param config Map with options:
 *   - appName: Application name (required)
 *   - imageTag: Image tag to deploy (required)
 *   - environment: Target environment (required: dev|staging|production)
 *   - namespace: Kubernetes namespace (default: environment name)
 *   - chartPath: Path to Helm chart (default: './helm/APP_NAME')
 *   - valuesFile: Values file override (default: values-ENVIRONMENT.yaml)
 *   - kubeconfigCredId: Kubeconfig credential ID (default: kubeconfig-ENVIRONMENT)
 *   - timeout: Helm timeout (default: '10m')
 *   - dryRun: Perform dry run only (default: false)
 */
def call(Map config = [:]) {
    ['appName', 'imageTag', 'environment'].each { required ->
        if (!config[required]) {
            error "deployToKubernetes: '${required}' is required"
        }
    }

    def defaults = [
        namespace      : config.environment,
        chartPath      : "./helm/${config.appName}",
        valuesFile     : "values-${config.environment}.yaml",
        kubeconfigCredId: "kubeconfig-${config.environment}",
        timeout        : '10m',
        dryRun         : false
    ]
    config = defaults + config

    def dryRunFlag = config.dryRun ? '--dry-run' : ''

    withCredentials([file(credentialsId: config.kubeconfigCredId, variable: 'KUBECONFIG')]) {
        sh """
            helm upgrade --install ${config.appName} ${config.chartPath} \
              --namespace ${config.namespace} \
              --create-namespace \
              --values ${config.chartPath}/${config.valuesFile} \
              --set image.tag=${config.imageTag} \
              --set deploymentTime="\$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              --atomic \
              --wait \
              --timeout ${config.timeout} \
              --history-max 10 \
              ${dryRunFlag}
        """

        // Verify deployment health
        if (!config.dryRun) {
            sh """
                kubectl rollout status deployment/${config.appName} \
                  --namespace ${config.namespace} \
                  --timeout=5m
            """
        }
    }
}
```

**Usage:**
```groovy
deployToKubernetes(
    appName: 'payment-service',
    imageTag: "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}",
    environment: 'production',
    timeout: '15m'
)
```

### vars/sendNotification.groovy

```groovy
/**
 * Send build notifications to Slack and/or email.
 *
 * @param config Map with options:
 *   - status: Build status (SUCCESS|FAILURE|UNSTABLE) — uses currentBuild.result if omitted
 *   - channel: Slack channel (default: '#devops-notifications')
 *   - emailTo: Email recipients (default: '')
 *   - message: Custom message (default: auto-generated)
 *   - attachLog: Attach build log to email (default: false)
 */
def call(Map config = [:]) {
    def status = config.status ?: currentBuild.result ?: 'UNKNOWN'
    def channel = config.channel ?: '#devops-notifications'

    def emoji  = [SUCCESS: '✅', FAILURE: '❌', UNSTABLE: '⚠️', ABORTED: '🛑']
    def colors = [SUCCESS: 'good', FAILURE: 'danger', UNSTABLE: 'warning', ABORTED: '#808080']

    def defaultMessage = "${emoji[status] ?: '❓'} *${env.JOB_NAME}* #${env.BUILD_NUMBER}: *${status}*\n" +
                         "Branch: `${env.GIT_BRANCH ?: 'unknown'}`\n" +
                         "Duration: ${currentBuild.durationString}\n" +
                         "<${env.BUILD_URL}|View Build>"

    def message = config.message ?: defaultMessage

    // Slack notification
    try {
        slackSend(
            channel: channel,
            color: colors[status] ?: '#808080',
            message: message
        )
    } catch (err) {
        echo "WARNING: Slack notification failed: ${err.message}"
    }

    // Email notification
    if (config.emailTo) {
        def subject = "${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        def body = """
Build Notification

Job:      ${env.JOB_NAME}
Build:    #${env.BUILD_NUMBER}
Status:   ${status}
Branch:   ${env.GIT_BRANCH ?: 'unknown'}
Commit:   ${env.GIT_COMMIT ?: 'unknown'}
Duration: ${currentBuild.durationString}
URL:      ${env.BUILD_URL}
Console:  ${env.BUILD_URL}console
        """

        emailext(
            to: config.emailTo,
            subject: subject,
            body: body,
            attachLog: config.attachLog ?: false
        )
    }
}
```

**Usage:**
```groovy
post {
    always {
        sendNotification(
            channel: '#team-alerts',
            emailTo: 'devops@example.com',
            attachLog: true
        )
    }
}
```

### vars/withSonarQualityGate.groovy

```groovy
/**
 * Run SonarQube analysis and wait for quality gate result.
 * Fails the build if quality gate fails.
 */
def call(Map config = [:], Closure body) {
    def serverName = config.serverName ?: 'sonarqube'
    def timeoutMinutes = config.timeout ?: 5

    withSonarQubeEnv(serverName) {
        body()
    }

    timeout(time: timeoutMinutes, unit: 'MINUTES') {
        def qg = waitForQualityGate()
        if (qg.status != 'OK') {
            error "SonarQube quality gate failed: status=${qg.status}"
        }
        echo "SonarQube quality gate passed: ${qg.status}"
    }
}
```

**Usage:**
```groovy
withSonarQualityGate(serverName: 'sonarqube-prod') {
    sh 'mvn sonar:sonar -B'
}
```

---

## `src/` — Groovy Classes

Classes in `src/` provide object-oriented, reusable logic.

### src/org/example/DockerUtils.groovy

```groovy
package org.example

class DockerUtils implements Serializable {

    private def script
    private String registry
    private String credentialsId

    DockerUtils(def script, String registry, String credentialsId = 'registry-credentials') {
        this.script = script
        this.registry = registry
        this.credentialsId = credentialsId
    }

    String buildImage(String name, String tag, Map buildArgs = [:]) {
        def fullName = "${registry}/${name}:${tag}"
        def buildArgsStr = buildArgs.collect { k, v -> "--build-arg ${k}=${v}" }.join(' ')

        script.sh """
            docker build ${buildArgsStr} \
              --tag ${fullName} \
              .
        """

        return fullName
    }

    void pushImage(String imageName) {
        script.withCredentials([script.usernamePassword(
            credentialsId: this.credentialsId,
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
        )]) {
            script.sh """
                echo "\${DOCKER_PASS}" | docker login ${registry} \
                  -u "\${DOCKER_USER}" --password-stdin
                docker push ${imageName}
                docker logout ${registry}
            """
        }
    }

    void scanImage(String imageName, String severity = 'HIGH,CRITICAL') {
        script.sh """
            trivy image \
              --exit-code 1 \
              --severity ${severity} \
              --format table \
              ${imageName}
        """
    }

    void removeImage(String imageName) {
        script.sh "docker rmi ${imageName} || true"
    }
}
```

**Usage in pipeline:**
```groovy
import org.example.DockerUtils

pipeline {
    agent { label 'linux && docker' }

    stages {
        stage('Build & Push') {
            steps {
                script {
                    def docker = new DockerUtils(this, 'registry.example.com')
                    def image = docker.buildImage('my-app', "${BUILD_NUMBER}")
                    docker.scanImage(image)
                    docker.pushImage(image)
                }
            }
        }
    }
}
```

### src/org/example/KubernetesUtils.groovy

```groovy
package org.example

class KubernetesUtils implements Serializable {

    private def script
    private String kubeconfigCredId

    KubernetesUtils(def script, String kubeconfigCredId) {
        this.script = script
        this.kubeconfigCredId = kubeconfigCredId
    }

    void deploy(String appName, String namespace, String imageTag) {
        script.withCredentials([script.file(
            credentialsId: this.kubeconfigCredId,
            variable: 'KUBECONFIG'
        )]) {
            script.sh """
                kubectl set image deployment/${appName} \
                  ${appName}=registry.example.com/${appName}:${imageTag} \
                  --namespace ${namespace}
                kubectl rollout status deployment/${appName} \
                  --namespace ${namespace} \
                  --timeout=5m
            """
        }
    }

    void helmDeploy(String releaseName, String chartPath, String namespace, Map values = [:]) {
        def setFlags = values.collect { k, v -> "--set ${k}=${v}" }.join(' ')

        script.withCredentials([script.file(
            credentialsId: this.kubeconfigCredId,
            variable: 'KUBECONFIG'
        )]) {
            script.sh """
                helm upgrade --install ${releaseName} ${chartPath} \
                  --namespace ${namespace} \
                  --create-namespace \
                  ${setFlags} \
                  --atomic \
                  --wait \
                  --timeout 10m
            """
        }
    }

    String getPodLogs(String namespace, String labelSelector) {
        script.withCredentials([script.file(
            credentialsId: this.kubeconfigCredId,
            variable: 'KUBECONFIG'
        )]) {
            return script.sh(
                script: "kubectl logs -l ${labelSelector} --namespace ${namespace} --tail=100",
                returnStdout: true
            ).trim()
        }
    }

    boolean isDeploymentHealthy(String appName, String namespace) {
        script.withCredentials([script.file(
            credentialsId: this.kubeconfigCredId,
            variable: 'KUBECONFIG'
        )]) {
            def result = script.sh(
                script: """
                    kubectl get deployment ${appName} \
                      --namespace ${namespace} \
                      -o jsonpath='{.status.readyReplicas}'
                """,
                returnStdout: true
            ).trim()
            return result?.isInteger() && result.toInteger() > 0
        }
    }
}
```

---

## `resources/` — Static Files

Store scripts, templates, and other static files in `resources/`.

### resources/scripts/smoke-test.sh

```bash
#!/bin/bash
set -euo pipefail

APP_URL="${1:?Usage: $0 <APP_URL>}"
MAX_RETRIES=10
RETRY_INTERVAL=10

echo "Running smoke tests against: ${APP_URL}"

for i in $(seq 1 ${MAX_RETRIES}); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/health")

    if [ "${STATUS}" = "200" ]; then
        echo "✅ Application is healthy (attempt ${i}/${MAX_RETRIES})"
        exit 0
    fi

    echo "⏳ Attempt ${i}/${MAX_RETRIES}: Health check returned ${STATUS}. Retrying in ${RETRY_INTERVAL}s..."
    sleep ${RETRY_INTERVAL}
done

echo "❌ Application health check failed after ${MAX_RETRIES} attempts"
exit 1
```

### resources/templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{APP_NAME}}
  namespace: {{NAMESPACE}}
  labels:
    app: {{APP_NAME}}
    version: {{IMAGE_TAG}}
spec:
  replicas: {{REPLICAS}}
  selector:
    matchLabels:
      app: {{APP_NAME}}
  template:
    metadata:
      labels:
        app: {{APP_NAME}}
        version: {{IMAGE_TAG}}
    spec:
      containers:
      - name: {{APP_NAME}}
        image: {{REGISTRY}}/{{APP_NAME}}:{{IMAGE_TAG}}
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

**Using resources in library:**
```groovy
def call(Map config) {
    def template = libraryResource('templates/deployment.yaml')
    def rendered = template
        .replace('{{APP_NAME}}', config.appName)
        .replace('{{NAMESPACE}}', config.namespace)
        .replace('{{IMAGE_TAG}}', config.imageTag)
        .replace('{{REPLICAS}}', config.replicas.toString())

    writeFile file: 'deployment.yaml', text: rendered
    sh 'kubectl apply -f deployment.yaml'
}
```

---

## Complete Enterprise Pipeline Using Shared Library

```groovy
@Library('jenkins-shared-library@main') _

import org.example.DockerUtils
import org.example.KubernetesUtils

pipeline {
    agent { label 'linux && docker' }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'])
        booleanParam(name: 'SKIP_TESTS', defaultValue: false)
        string(name: 'IMAGE_TAG', defaultValue: '', description: 'Override image tag (leave empty to auto-generate)')
    }

    environment {
        APP_NAME  = 'payment-service'
        REGISTRY  = 'registry.example.com'
        IMAGE_TAG = params.IMAGE_TAG ?: "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                buildMavenApp(
                    skipTests: params.SKIP_TESTS,
                    extraArgs: '-Dmaven.repo.local=/cache/.m2'
                )
            }
        }

        stage('Test') {
            when { expression { !params.SKIP_TESTS } }
            steps {
                sh 'mvn test -B --no-transfer-progress'
            }
            post {
                always { junit 'target/surefire-reports/*.xml' }
            }
        }

        stage('Code Quality') {
            when { expression { !params.SKIP_TESTS } }
            steps {
                withSonarQualityGate {
                    sh 'mvn sonar:sonar -B --no-transfer-progress'
                }
            }
        }

        stage('Docker Build & Scan') {
            steps {
                script {
                    def docker = new DockerUtils(this, env.REGISTRY)
                    def imageRef = docker.buildImage(env.APP_NAME, env.IMAGE_TAG)
                    docker.scanImage(imageRef)
                    docker.pushImage(imageRef)
                }
            }
        }

        stage('Deploy') {
            steps {
                deployToKubernetes(
                    appName: env.APP_NAME,
                    imageTag: env.IMAGE_TAG,
                    environment: params.ENVIRONMENT
                )
            }
        }

        stage('Smoke Tests') {
            steps {
                sh """
                    bash <(curl -s https://raw.githubusercontent.com/org/jenkins-shared-library/main/resources/scripts/smoke-test.sh) \
                        https://${env.APP_NAME}.${params.ENVIRONMENT}.example.com
                """
            }
        }
    }

    post {
        always {
            cleanWs()
            sendNotification(
                channel: '#payments-team',
                emailTo: 'payments@example.com'
            )
        }
    }
}
```

---

## Testing Shared Libraries

### Unit Testing with JenkinsPipelineUnit

```groovy
// test/vars/BuildMavenAppTest.groovy
import org.junit.Before
import org.junit.Test
import com.lesfurets.jenkins.unit.BasePipelineTest

class BuildMavenAppTest extends BasePipelineTest {

    @Before
    void setUp() {
        super.setUp()
    }

    @Test
    void 'buildMavenApp with defaults runs mvn clean package'() {
        def script = loadScript('vars/buildMavenApp.groovy')

        script.call()

        assertJobStatusSuccess()
        printCallStack()
    }

    @Test
    void 'buildMavenApp with skipTests adds DskipTests flag'() {
        def script = loadScript('vars/buildMavenApp.groovy')

        script.call(skipTests: true)

        assertCallStack().contains('mvn clean package -DskipTests')
    }
}
```

```gradle
// build.gradle
plugins {
    id 'groovy'
}

dependencies {
    testImplementation 'com.lesfurets:jenkins-pipeline-unit:1.21'
    testImplementation 'junit:junit:4.13.2'
}
```

---

## Versioning Strategy

```
jenkins-shared-library/
└── (git repository with semver tags)

Version examples:
  main     → latest (unstable, for testing)
  develop  → integration branch
  v1.0.0   → stable release
  v1.1.0   → minor feature additions
  v2.0.0   → breaking changes
```

**Pinning versions in pipelines:**
```groovy
// RECOMMENDED for production: pin to a specific version
@Library('jenkins-shared-library@v1.2.3') _

// AVOID for production: floating to branch head
@Library('jenkins-shared-library@main') _
```

---

## Best Practices

1. **Version your shared library** — pin pipelines to specific versions
2. **Write tests** for shared library functions using JenkinsPipelineUnit
3. **Document every function** — use Groovydoc comments
4. **Keep functions focused** — one function, one responsibility
5. **Use meaningful parameter names** — prefer maps over positional args
6. **Validate required parameters** — fail early with clear error messages
7. **Handle credentials in the library** — standardize secret management
8. **Implement sensible defaults** — reduce boilerplate in calling pipelines
9. **Make library functions idempotent** — safe to call multiple times
10. **Separate library releases from app releases** — different repos and cadences

---

## References

- [Jenkins Shared Libraries Documentation](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- [Jenkins Pipeline Unit Testing](https://github.com/jenkinsci/JenkinsPipelineUnit)
- [Groovydoc Reference](https://groovy-lang.org/groovydoc.html)
- [Plugin: Pipeline: Shared Groovy Libraries](https://plugins.jenkins.io/workflow-cps-global-lib/)

---

## Next Section

[09 — Docker Integration →](../09-docker-integration/README.md)
