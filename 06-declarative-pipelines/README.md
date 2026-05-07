# 06 — Declarative Pipelines

## Overview

Declarative Pipeline is the modern, recommended approach for defining Jenkins pipelines. It uses a structured, opinionated DSL that enforces best practices while remaining highly flexible. This section covers Declarative Pipeline deeply — from syntax to advanced patterns used in production.

---

## Objectives

- Master the complete Declarative Pipeline syntax
- Understand every directive and option
- Build production-grade pipelines for multiple languages
- Use matrix builds for cross-platform testing
- Implement advanced patterns: multi-branch, organization pipelines
- Apply pipeline optimization techniques

---

## Prerequisites

- Section 05 (Pipeline fundamentals) completed
- Jenkins with Pipeline plugin installed
- A Git repository to connect

---

## Complete Declarative Pipeline Syntax Reference

```groovy
pipeline {
    // ─── AGENT ───────────────────────────────────────────────────
    agent {
        label 'linux && docker'
    }

    // ─── OPTIONS ─────────────────────────────────────────────────
    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))
        disableConcurrentBuilds(abortPrevious: true)
        skipStagesAfterUnstable()
        preserveStashes(buildCount: 5)
        durabilityHint('PERFORMANCE_OPTIMIZED')
    }

    // ─── TRIGGERS ─────────────────────────────────────────────────
    triggers {
        // Poll SCM every 5 minutes (prefer webhooks)
        pollSCM('H/5 * * * *')
        // Run nightly at midnight
        cron('H 0 * * *')
        // Trigger when upstream job completes
        upstream(upstreamProjects: 'my-upstream-job', threshold: hudson.model.Result.SUCCESS)
    }

    // ─── TOOLS ────────────────────────────────────────────────────
    tools {
        // Names must match Manage Jenkins → Tools configuration
        jdk 'JDK-21'
        maven 'Maven-3.9'
        nodejs 'Node-20'
    }

    // ─── PARAMETERS ───────────────────────────────────────────────
    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branch to build')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'])
        booleanParam(name: 'SKIP_TESTS', defaultValue: false)
        text(name: 'RELEASE_NOTES', defaultValue: '', description: 'Release notes')
        file(name: 'CONFIG_FILE', description: 'Upload configuration file')
        password(name: 'DEPLOY_TOKEN', defaultValue: '', description: 'Deploy token')
    }

    // ─── ENVIRONMENT ──────────────────────────────────────────────
    environment {
        APP_NAME     = 'my-app'
        REGISTRY     = 'registry.example.com'
        IMAGE_TAG    = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        DOCKER_CREDS = credentials('registry-credentials')
        SONAR_TOKEN  = credentials('sonar-token')
    }

    // ─── STAGES ───────────────────────────────────────────────────
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
    }

    // ─── POST ─────────────────────────────────────────────────────
    post {
        always { cleanWs() }
        success { echo 'Success' }
        failure { echo 'Failure' }
    }
}
```

---

## Advanced Agent Configurations

### Static Label Agent

```groovy
agent { label 'linux && java && docker' }
```

### Docker Agent with Custom Image

```groovy
agent {
    docker {
        image 'maven:3.9-eclipse-temurin-21-alpine'
        label 'linux'
        registryUrl 'https://registry.example.com'
        registryCredentialsId 'registry-credentials'
        args '''
            -v /root/.m2:/root/.m2
            -v /var/run/docker.sock:/var/run/docker.sock
            --network host
        '''
        alwaysPull true
    }
}
```

### Kubernetes Agent

```groovy
agent {
    kubernetes {
        label 'jenkins-agent'
        defaultContainer 'jnlp'
        yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-agent
spec:
  serviceAccountName: jenkins-agent
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest-jdk21
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
  - name: maven
    image: maven:3.9-eclipse-temurin-21
    command: ["sleep", "infinity"]
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 2Gi
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
  volumes:
  - name: maven-cache
    persistentVolumeClaim:
      claimName: maven-cache-pvc
'''
    }
}
```

---

## Matrix Builds

Matrix builds run the same stages across multiple configurations simultaneously.

```groovy
pipeline {
    agent none

    stages {
        stage('Cross-Platform Tests') {
            matrix {
                axes {
                    axis {
                        name 'OS'
                        values 'linux', 'windows', 'macos'
                    }
                    axis {
                        name 'JAVA_VERSION'
                        values '17', '21'
                    }
                }

                excludes {
                    // Skip macOS + Java 17 combination
                    exclude {
                        axis {
                            name 'OS'
                            values 'macos'
                        }
                        axis {
                            name 'JAVA_VERSION'
                            values '17'
                        }
                    }
                }

                stages {
                    stage('Test') {
                        agent { label "${OS}" }
                        tools { jdk "JDK-${JAVA_VERSION}" }
                        steps {
                            echo "Testing on ${OS} with Java ${JAVA_VERSION}"
                            sh 'mvn test -B'
                        }
                        post {
                            always {
                                junit 'target/surefire-reports/*.xml'
                            }
                        }
                    }
                }
            }
        }
    }
}
```

**Matrix produces:**
```
Cross-Platform Tests
├── (linux, 17)
├── (linux, 21)
├── (windows, 17)
├── (windows, 21)
└── (macos, 21)   ← macos+17 excluded
```

---

## Complete Production Pipeline Examples

### Node.js Application Pipeline

```groovy
pipeline {
    agent {
        docker {
            image 'node:20-alpine'
            args '-v /tmp/npm-cache:/root/.npm'
        }
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        APP_NAME    = 'my-node-app'
        NODE_ENV    = 'test'
        NPM_CONFIG_CACHE = '/root/.npm'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'node --version && npm --version'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci --prefer-offline'
            }
        }

        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'npm run test:ci'
            }
            post {
                always {
                    junit 'test-results/junit.xml'
                    publishHTML target: [
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ]
                }
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Docker Build & Push') {
            when { anyOf { branch 'main'; branch 'develop' } }
            environment {
                DOCKER_CREDS = credentials('dockerhub-credentials')
                IMAGE_TAG    = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
            }
            steps {
                sh """
                    docker build -t myorg/${APP_NAME}:${IMAGE_TAG} .
                    echo "${DOCKER_CREDS_PSW}" | docker login -u "${DOCKER_CREDS_USR}" --password-stdin
                    docker push myorg/${APP_NAME}:${IMAGE_TAG}
                    docker tag myorg/${APP_NAME}:${IMAGE_TAG} myorg/${APP_NAME}:latest
                    docker push myorg/${APP_NAME}:latest
                """
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl set image deployment/${APP_NAME} \
                          ${APP_NAME}=myorg/${APP_NAME}:${BUILD_NUMBER}-\$(git rev-parse --short HEAD) \
                          -n production
                        kubectl rollout status deployment/${APP_NAME} -n production --timeout=5m
                    """
                }
            }
        }
    }

    post {
        always { cleanWs() }
        success {
            slackSend color: 'good',
                      message: "✅ ${JOB_NAME} #${BUILD_NUMBER} passed"
        }
        failure {
            slackSend color: 'danger',
                      message: "❌ ${JOB_NAME} #${BUILD_NUMBER} FAILED - ${BUILD_URL}"
        }
    }
}
```

### Python Application Pipeline

```groovy
pipeline {
    agent {
        docker {
            image 'python:3.12-slim'
            args '-v /tmp/pip-cache:/root/.cache/pip'
        }
    }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        PYTHONPATH = "${WORKSPACE}"
        PIP_NO_CACHE_DIR = 'false'
        PIP_CACHE_DIR = '/root/.cache/pip'
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    python --version
                    pip install --upgrade pip
                    pip install -r requirements.txt
                    pip install -r requirements-dev.txt
                '''
            }
        }

        stage('Lint') {
            parallel {
                stage('Flake8') {
                    steps { sh 'flake8 src/ tests/ --max-line-length=120' }
                }
                stage('Black') {
                    steps { sh 'black --check src/ tests/' }
                }
                stage('isort') {
                    steps { sh 'isort --check-only src/ tests/' }
                }
                stage('mypy') {
                    steps { sh 'mypy src/' }
                }
            }
        }

        stage('Security') {
            steps {
                sh 'bandit -r src/ -f json -o bandit-report.json || true'
                sh 'safety check --json || true'
            }
        }

        stage('Tests') {
            steps {
                sh '''
                    pytest tests/ \
                        --junitxml=test-results/junit.xml \
                        --cov=src \
                        --cov-report=xml:coverage.xml \
                        --cov-report=html:coverage-html \
                        -v
                '''
            }
            post {
                always {
                    junit 'test-results/junit.xml'
                    publishHTML target: [
                        reportDir: 'coverage-html',
                        reportFiles: 'index.html',
                        reportName: 'Coverage'
                    ]
                }
            }
        }

        stage('Build Docker Image') {
            when { branch 'main' }
            steps {
                script {
                    def imageTag = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
                    withCredentials([usernamePassword(
                        credentialsId: 'registry-credentials',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )]) {
                        sh """
                            docker build -t registry.example.com/my-python-app:${imageTag} .
                            echo "${REGISTRY_PASS}" | docker login registry.example.com \
                                -u "${REGISTRY_USER}" --password-stdin
                            docker push registry.example.com/my-python-app:${imageTag}
                        """
                    }
                }
            }
        }
    }

    post {
        always { cleanWs() }
    }
}
```

---

## Multi-Branch Pipeline

Multi-branch pipelines automatically discover branches and PRs in a repository.

### Creating a Multi-Branch Pipeline

1. **New Item → Multibranch Pipeline**
2. Configure **Branch Sources** → GitHub/GitLab
3. Configure **Build Configuration** → Jenkinsfile path: `Jenkinsfile`
4. Configure **Scan Triggers** → 1 day (webhooks preferred)

### Branch-Specific Logic

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Deploy Feature') {
            when {
                expression { env.BRANCH_NAME.startsWith('feature/') }
            }
            steps {
                echo "Deploying feature branch: ${env.BRANCH_NAME}"
                sh './deploy.sh dev'
            }
        }

        stage('Deploy Staging') {
            when { branch 'develop' }
            steps {
                sh './deploy.sh staging'
            }
        }

        stage('Deploy Production') {
            when { branch 'main' }
            steps {
                input 'Deploy to production?'
                sh './deploy.sh production'
            }
        }

        stage('PR Validation') {
            when { changeRequest() }
            steps {
                echo "Validating PR: ${env.CHANGE_ID} from ${env.CHANGE_BRANCH}"
                sh 'mvn verify'
            }
        }
    }
}
```

### Branch Source Configuration (GitHub)

```
Branch Sources:
  GitHub:
    Credentials: github-credentials
    Repository: https://github.com/org/repo
    
    Behaviors:
    - Discover branches: Exclude branches filed as PRs
    - Discover pull requests from origin: Merging with base branch
    - Discover pull requests from forks: Trust contributors

Build Configuration:
  Mode: by Jenkinsfile
  Script Path: Jenkinsfile

Scan Multibranch Pipeline Triggers:
  Periodically if not otherwise run: 1 day
```

---

## Organization Folders

Organization Folders automatically discover and create pipelines for every repository in a GitHub/GitLab organization.

```
New Item → GitHub Organization

GitHub Organization:
  Credentials: github-credentials
  Owner: my-github-org
  
  Repository name pattern: .*                    # All repos
  # or:
  Repository name pattern: service-.*            # Only service repos
  
  Script Path: Jenkinsfile
```

Every repository with a `Jenkinsfile` gets automatically scanned and a pipeline created.

---

## Pipeline Optimization Techniques

### 1. Parallel Stages for Speed

```groovy
stage('Quality Gates') {
    parallel {
        stage('Unit Tests') {
            steps { sh 'mvn test' }
        }
        stage('SonarQube') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }
        stage('Dependency Check') {
            steps { sh 'mvn dependency-check:check' }
        }
        stage('Lint') {
            steps { sh 'mvn checkstyle:check' }
        }
    }
}
```

### 2. `when { beforeAgent true }` — Skip Agent Allocation

```groovy
stage('Deploy Production') {
    when {
        beforeAgent true   // Evaluate BEFORE requesting an agent
        branch 'main'
    }
    agent { label 'production-deploy' }
    steps { sh './deploy-production.sh' }
}
```

### 3. Stash for Cross-Agent Artifact Passing

```groovy
stage('Build') {
    agent { label 'build-agent' }
    steps {
        sh 'mvn package'
        stash name: 'artifacts', includes: 'target/*.jar,scripts/**'
    }
}

stage('Deploy') {
    agent { label 'deploy-agent' }
    steps {
        unstash 'artifacts'
        sh './scripts/deploy.sh'
    }
}
```

### 4. Cache Dependencies

```groovy
// Maven cache via Docker volume mount
agent {
    docker {
        image 'maven:3.9-eclipse-temurin-21'
        args '-v /data/maven-cache:/root/.m2'
    }
}

// npm cache
agent {
    docker {
        image 'node:20-alpine'
        args '-v /data/npm-cache:/root/.npm'
    }
}
```

### 5. Fail Fast in Parallel

```groovy
stage('Tests') {
    failFast true
    parallel {
        stage('Unit') { steps { sh 'mvn test -Punit' } }
        stage('Integration') { steps { sh 'mvn test -Pintegration' } }
        stage('E2E') { steps { sh 'mvn test -Pe2e' } }
    }
}
```

---

## Jenkinsfile Validation

### Validate Without Running

```bash
# Jenkins CLI validation
curl -X POST \
  http://jenkins.example.com/pipeline-model-converter/validate \
  --user admin:TOKEN \
  -F "jenkinsfile=<Jenkinsfile"

# Or use Jenkins Replay feature in the UI
# Navigate to a build → Replay → modify and run
```

### Linting with NPE Prevention

```bash
# Install Jenkins Pipelines Linter (npm-based)
npm install -g jenkins-pipeline-linter-connector

# Or validate via API
curl --silent --user admin:TOKEN \
  -X POST -F "jenkinsfile=<${WORKSPACE}/Jenkinsfile" \
  http://jenkins.example.com/pipeline-model-converter/validateJenkinsfile
```

---

## Shared Library Integration

```groovy
// Load shared library from GitHub
@Library('jenkins-shared-library@main') _

pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                // Call shared library function
                buildMavenApp(
                    javaVersion: '21',
                    skipTests: false
                )
            }
        }

        stage('Deploy') {
            steps {
                // Call another shared library function
                deployToKubernetes(
                    environment: params.ENVIRONMENT,
                    imageTag: env.IMAGE_TAG,
                    namespace: 'production'
                )
            }
        }
    }
}
```

---

## Security in Declarative Pipelines

### Credentials Binding

```groovy
environment {
    // Username/password
    DOCKER_CREDS = credentials('dockerhub')
    // Creates: DOCKER_CREDS_USR, DOCKER_CREDS_PSW

    // Secret text
    SONAR_TOKEN = credentials('sonar-token')
    // Creates: SONAR_TOKEN (masked in logs)
}

steps {
    // SSH key
    sshagent(credentials: ['deploy-ssh-key']) {
        sh 'ssh deploy@server.example.com "./deploy.sh"'
    }

    // Secret file
    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
        sh 'kubectl apply -f deployment.yaml'
    }

    // Certificate
    withCredentials([certificate(
        credentialsId: 'client-cert',
        keystoreVariable: 'KEYSTORE',
        passwordVariable: 'KEYSTORE_PASSWORD'
    )]) {
        sh 'curl --cert ${KEYSTORE} ...'
    }
}
```

### Secret Masking Verification

```groovy
steps {
    // Jenkins automatically masks credential values in logs
    // This will show: docker login -u *** --password ***
    sh 'docker login -u ${DOCKER_CREDS_USR} -p ${DOCKER_CREDS_PSW} registry.example.com'

    // NEVER use echo with credentials
    // sh "echo My secret is: ${SONAR_TOKEN}"  // DON'T DO THIS
}
```

---

## Common Patterns

### Skip Build for Documentation Changes

```groovy
stages {
    stage('Check Changes') {
        steps {
            script {
                def changedFiles = sh(
                    script: 'git diff --name-only HEAD~1',
                    returnStdout: true
                ).trim().split('\n')

                def onlyDocs = changedFiles.every { it.matches('.*\\.(md|txt|rst)') }
                if (onlyDocs) {
                    currentBuild.result = 'SUCCESS'
                    error('Only documentation changes — skipping build.')
                }
            }
        }
    }
    // ... rest of stages
}
```

### Dynamic Stage Creation

```groovy
stages {
    stage('Deploy to Environments') {
        steps {
            script {
                def environments = ['dev', 'staging', 'uat']
                environments.each { env ->
                    stage("Deploy to ${env.toUpperCase()}") {
                        sh "./deploy.sh ${env}"
                        input "Confirm ${env} deployment passed?"
                    }
                }
            }
        }
    }
}
```

### Abort Previous Builds (for PRs)

```groovy
options {
    disableConcurrentBuilds(abortPrevious: true)
}
```

---

## Troubleshooting

### Syntax Errors

```
Error: Expected one of "agent" "post" "stages" "environment" ...
→ Check your Declarative structure — all blocks must be in the right place
→ Use Pipeline Syntax Generator in Jenkins UI

Error: No such DSL method 'xxx'
→ Missing plugin or incorrect step name
→ Check Pipeline Steps Reference
```

### Agent Not Available

```
Error: No agents with label 'linux && docker' found
→ Verify agents are online: Manage Jenkins → Nodes
→ Verify labels match: Node → Configure → Labels
→ Check if Docker is installed on the agent
```

### Credentials Not Found

```
Error: CredentialNotFoundException: No credentials found with id 'my-creds'
→ Verify credential ID: Manage Jenkins → Credentials
→ Verify credential scope: Global vs. Folder
→ Verify job has access to the credential store
```

---

## References

- [Declarative Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Multi-Branch Pipeline](https://www.jenkins.io/doc/book/pipeline/multibranch/)
- [Pipeline Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)
- [Credentials Binding Plugin](https://plugins.jenkins.io/credentials-binding/)

---

## Next Section

[07 — Scripted Pipelines →](../07-scripted-pipelines/README.md)
