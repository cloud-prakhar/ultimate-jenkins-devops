# 05 — Jenkins Pipelines

## Overview

Jenkins Pipeline is the recommended approach for CI/CD in modern Jenkins. A Pipeline defines your entire build, test, and deployment process as code in a `Jenkinsfile`, committed to your repository. This section covers Pipeline fundamentals — the concepts, syntax, and key features that underpin both Declarative and Scripted pipelines.

## Module Status

| Field | Value |
| --- | --- |
| Status | 🚧 In Progress |
| Environment | Local lab or any Jenkins instance |
| Next practical lab | [Project 01 - Python Flask Todo API](../15-real-world-projects/01-python-flask-todo-api/README.md) |
| Migration note | This module still needs a full learner-template migration with lab starter and solution assets |

---

## Objectives

- Understand what Pipelines are and why they replaced Freestyle jobs
- Understand the Jenkinsfile concept
- Learn the Pipeline building blocks: stages, steps, agents, post
- Understand Pipeline execution model
- Use environment variables and parameters
- Handle credentials securely in Pipelines
- Use `when`, `parallel`, and `input` directives
- Trigger pipelines from SCM
- Understand Pipeline durability and checkpointing

---

## Why Pipelines?

### The Pipeline-as-Code Advantage

| Concern | Freestyle | Pipeline |
|---------|-----------|----------|
| Version control | ❌ Config in Jenkins DB | ✅ Jenkinsfile in git |
| Code review | ❌ Not possible | ✅ PR review of Jenkinsfile |
| Audit history | ❌ Jenkins log only | ✅ git blame/log |
| Disaster recovery | ❌ Manual reconfiguration | ✅ Re-create from Jenkinsfile |
| Visualization | Basic | ✅ Stage view, Blue Ocean |
| Parallel stages | ❌ | ✅ Native support |
| Conditions | Limited | ✅ Full Groovy |
| Resume on failure | ❌ | ✅ Checkpoints (with plugin) |
| Shared logic | ❌ | ✅ Shared libraries |

---

## The Jenkinsfile

A `Jenkinsfile` is a text file that contains the definition of a Jenkins Pipeline. It is checked into source control at the root of your repository.

```text
my-project/
├── src/
├── tests/
├── Dockerfile
├── Jenkinsfile          ← Pipeline definition
└── pom.xml
```

### Two Pipeline Syntaxes

Jenkins supports two pipeline syntaxes:

| Aspect | Declarative | Scripted |
| --- | --- | --- |
| Syntax | Structured, opinionated | Full Groovy |
| Learning curve | Simpler | Steeper |
| Validation | Better (fails early) | Minimal |
| Flexibility | Good for most cases | Maximum |
| Recommendation | Use for ~95% of pipelines | Only when Declarative cannot express it |

Declarative:

```groovy
pipeline {
    agent { label 'linux' }
    stages {
        stage('Build') {
            steps {
                sh 'mvn package'
            }
        }
    }
}
```

Scripted:

```groovy
node('linux') {
    stage('Build') {
        sh 'mvn package'
    }
}
```

> **Use Declarative** for 95% of use cases. It is simpler, better documented, and has IDE support.
> **Use Scripted** only when Declarative cannot express what you need.

---

## Declarative Pipeline Structure

```groovy
pipeline {                          // Required: top-level block
    agent { ... }                   // Required: where to run

    options { ... }                 // Optional: pipeline-level options

    parameters { ... }              // Optional: build parameters

    environment { ... }             // Optional: environment variables

    triggers { ... }                // Optional: automated triggers

    stages {                        // Required: contains all stages
        stage('Stage Name') {       // Required: at least one stage
            agent { ... }          // Optional: override agent for this stage
            when { ... }           // Optional: conditional execution
            environment { ... }   // Optional: stage-level environment
            steps {                // Required: the actual work
                // Steps go here
            }
            post { ... }          // Optional: stage-level post actions
        }
    }

    post { ... }                    // Optional: pipeline-level post actions
}
```

---

## Core Pipeline Blocks

### `agent` — Where to Run

```groovy
// Run on any available agent
agent any

// Run on the Jenkins controller (AVOID in production)
agent none  // No global agent; each stage must define its own

// Run on a specific labeled agent
agent { label 'linux' }
agent { label 'linux && docker' }

// Run in a Docker container
agent {
    docker {
        image 'maven:3.9-eclipse-temurin-21'
        label 'linux'
        args '-v /root/.m2:/root/.m2'
    }
}

// Run in a Kubernetes pod (production)
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.9-eclipse-temurin-21
    command: ["sleep", "infinity"]
  - name: docker
    image: docker:dind
    securityContext:
      privileged: true
'''
        defaultContainer 'maven'
    }
}
```

### `options` — Pipeline Behavior

```groovy
options {
    timestamps()                              // Add timestamps to log
    ansiColor('xterm')                        // Colored output
    timeout(time: 30, unit: 'MINUTES')        // Fail if > 30 min
    buildDiscarder(logRotator(
        numToKeepStr: '10',                   // Keep last 10 builds
        daysToKeepStr: '30'                   // Or 30 days
    ))
    disableConcurrentBuilds()                 // One build at a time
    skipDefaultCheckout()                     // Don't auto-checkout SCM
    retry(3)                                  // Retry on failure
    preserveStashes(buildCount: 5)            // Keep stashes for 5 builds
}
```

### `parameters` — Build Inputs

```groovy
parameters {
    string(
        name: 'BRANCH',
        defaultValue: 'main',
        description: 'Branch to build'
    )
    choice(
        name: 'ENVIRONMENT',
        choices: ['dev', 'staging', 'production'],
        description: 'Deployment target'
    )
    booleanParam(
        name: 'SKIP_TESTS',
        defaultValue: false,
        description: 'Skip test execution'
    )
    text(
        name: 'RELEASE_NOTES',
        defaultValue: '',
        description: 'Release notes for this deployment'
    )
    password(
        name: 'MANUAL_SECRET',
        defaultValue: '',
        description: 'One-time secret for this build'
    )
}

// Access in steps:
// ${params.BRANCH}
// ${params.ENVIRONMENT}
// ${params.SKIP_TESTS}
```

### `environment` — Variables

```groovy
environment {
    // Static values
    APP_NAME    = 'my-application'
    REGISTRY    = 'registry.example.com'

    // Dynamic values (Groovy expressions)
    IMAGE_TAG   = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"

    // From credentials (credentials() binding)
    DOCKER_CREDS = credentials('dockerhub-credentials')
    // Creates: DOCKER_CREDS_USR and DOCKER_CREDS_PSW variables

    // Secret text
    SONAR_TOKEN = credentials('sonar-token')
}
```

### `stages` and `stage`

```groovy
stages {
    stage('Checkout') {
        steps {
            checkout scm
            // or explicit:
            git branch: 'main',
                credentialsId: 'github-credentials',
                url: 'https://github.com/org/repo.git'
        }
    }

    stage('Build') {
        steps {
            sh 'mvn clean package -DskipTests'
        }
    }

    stage('Test') {
        steps {
            sh 'mvn test'
        }
        post {
            always {
                junit 'target/surefire-reports/*.xml'
            }
        }
    }

    stage('Parallel Stages') {
        parallel {
            stage('Unit Tests') {
                steps { sh 'mvn test -Dtest=UnitTests' }
            }
            stage('Integration Tests') {
                steps { sh 'mvn test -Dtest=IntegrationTests' }
            }
            stage('Security Scan') {
                steps { sh 'trivy image my-app:latest' }
            }
        }
    }
}
```

### `steps` — The Work

```groovy
steps {
    // Shell command (Linux/Mac)
    sh 'mvn clean package'
    sh '''
        echo "Multi-line"
        mvn clean package
        echo "Done"
    '''

    // Windows batch command
    bat 'mvn clean package'

    // Print message
    echo 'Starting build...'

    // Source control checkout
    checkout scm

    // Read/write files
    writeFile file: 'version.txt', text: "${BUILD_NUMBER}"
    def content = readFile('version.txt').trim()

    // Stash files between stages (different agents)
    stash name: 'built-artifacts', includes: 'target/*.jar'
    unstash 'built-artifacts'

    // Archive artifacts
    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true

    // JUnit results
    junit 'target/surefire-reports/*.xml'

    // Sleep (avoid if possible)
    sleep time: 10, unit: 'SECONDS'

    // Retry a block
    retry(3) {
        sh './flaky-script.sh'
    }

    // Timeout a block
    timeout(time: 5, unit: 'MINUTES') {
        sh './long-running-script.sh'
    }

    // Trigger another job
    build job: 'downstream-job',
          parameters: [string(name: 'VERSION', value: "${BUILD_NUMBER}")]
}
```

### `when` — Conditional Stages

```groovy
stage('Deploy to Production') {
    when {
        // Only on main branch
        branch 'main'
    }
    steps { sh './deploy.sh production' }
}

stage('Deploy to Feature') {
    when {
        // Only on feature branches
        branch pattern: 'feature/.*', comparator: 'REGEXP'
    }
    steps { sh './deploy.sh dev' }
}

stage('Skip if No Tests') {
    when {
        // Only if parameter is set
        expression { return params.SKIP_TESTS == false }
    }
    steps { sh 'mvn test' }
}

stage('Tag Release') {
    when {
        // Multiple conditions (AND)
        allOf {
            branch 'main'
            not { changeRequest() }
        }
    }
    steps { sh './tag-release.sh' }
}

stage('Deploy') {
    when {
        // Evaluate before agent is allocated (saves resources)
        beforeAgent true
        branch 'main'
    }
    agent { label 'deploy-agent' }
    steps { sh './deploy.sh' }
}
```

### `post` — Post Actions

```groovy
post {
    always {
        // Always runs, regardless of outcome
        cleanWs()                    // Clean workspace
        junit 'test-results/*.xml'  // Always publish test results
    }
    success {
        // Only on success
        archiveArtifacts 'target/*.jar'
        slackSend color: 'good', message: "Build #${BUILD_NUMBER} succeeded"
    }
    failure {
        // Only on failure
        emailext(
            to: 'team@example.com',
            subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER}",
            body: "Build failed: ${BUILD_URL}"
        )
        slackSend color: 'danger', message: "Build #${BUILD_NUMBER} FAILED"
    }
    unstable {
        // Tests failed but build succeeded
        slackSend color: 'warning', message: "Build #${BUILD_NUMBER} unstable (tests failed)"
    }
    aborted {
        // Build was manually aborted
        echo 'Build was aborted'
    }
    changed {
        // Build result changed from last build
        echo 'Build result changed'
    }
    fixed {
        // Was failing, now passing
        slackSend color: 'good', message: "Build #${BUILD_NUMBER} is fixed!"
    }
    regression {
        // Was passing, now failing
        slackSend color: 'danger', message: "Build #${BUILD_NUMBER} regressed!"
    }
}
```

### `input` — Manual Approval Gate

```groovy
stage('Deploy to Production') {
    when { branch 'main' }
    steps {
        timeout(time: 24, unit: 'HOURS') {
            input(
                message: "Deploy version ${BUILD_NUMBER} to production?",
                ok: 'Deploy',
                submitter: 'release-managers,senior-devops',
                parameters: [
                    choice(
                        name: 'PROCEED',
                        choices: ['yes', 'no'],
                        description: 'Confirm deployment'
                    )
                ]
            )
        }
        sh './deploy.sh production'
    }
}
```

---

## Complete Example: Java CI/CD Pipeline

```groovy
pipeline {
    agent {
        docker {
            image 'maven:3.9-eclipse-temurin-21'
            args '-v /root/.m2:/root/.m2 -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Branch to build')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Deploy target')
    }

    environment {
        APP_NAME    = 'my-java-app'
        REGISTRY    = 'registry.example.com'
        IMAGE_TAG   = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        DOCKER_CREDS = credentials('registry-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean compile -B --no-transfer-progress'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test -B --no-transfer-progress'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    publishHTML target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/site/jacoco',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ]
                }
            }
        }

        stage('Code Quality') {
            parallel {
                stage('SonarQube') {
                    steps {
                        withSonarQubeEnv('sonarqube-server') {
                            sh 'mvn sonar:sonar -B --no-transfer-progress'
                        }
                    }
                }
                stage('Dependency Check') {
                    steps {
                        sh 'mvn org.owasp:dependency-check-maven:check -B'
                    }
                }
            }
        }

        stage('Package') {
            steps {
                sh 'mvn package -DskipTests -B --no-transfer-progress'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                stash name: 'jar-artifact', includes: 'target/*.jar'
            }
        }

        stage('Docker Build') {
            when {
                anyOf { branch 'main'; branch 'develop' }
            }
            steps {
                unstash 'jar-artifact'
                sh """
                    docker build \
                      --tag ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} \
                      --tag ${REGISTRY}/${APP_NAME}:latest \
                      --build-arg JAR_FILE=target/*.jar \
                      .
                """
            }
        }

        stage('Security Scan') {
            when {
                anyOf { branch 'main'; branch 'develop' }
            }
            steps {
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
            }
        }

        stage('Docker Push') {
            when {
                anyOf { branch 'main'; branch 'develop' }
            }
            steps {
                sh """
                    echo "${DOCKER_CREDS_PSW}" | docker login ${REGISTRY} -u ${DOCKER_CREDS_USR} --password-stdin
                    docker push ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY}/${APP_NAME}:latest
                """
            }
        }

        stage('Deploy Dev') {
            when { branch 'develop' }
            steps {
                sh "./scripts/deploy.sh dev ${IMAGE_TAG}"
            }
        }

        stage('Deploy Staging') {
            when { branch 'main' }
            steps {
                sh "./scripts/deploy.sh staging ${IMAGE_TAG}"
            }
        }

        stage('Integration Tests') {
            when { branch 'main' }
            steps {
                sh 'mvn verify -Pintegration-tests -B'
            }
        }

        stage('Approve Production Deploy') {
            when { branch 'main' }
            steps {
                timeout(time: 24, unit: 'HOURS') {
                    input message: "Deploy ${IMAGE_TAG} to production?", ok: 'Deploy'
                }
            }
        }

        stage('Deploy Production') {
            when { branch 'main' }
            steps {
                sh "./scripts/deploy.sh production ${IMAGE_TAG}"
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            slackSend(
                color: 'good',
                message: "✅ ${JOB_NAME} #${BUILD_NUMBER} succeeded (${IMAGE_TAG}) - ${BUILD_URL}"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "❌ ${JOB_NAME} #${BUILD_NUMBER} FAILED - ${BUILD_URL}"
            )
            emailext(
                to: 'devops-team@example.com',
                subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER}",
                body: """
Build failed!

Job: ${JOB_NAME}
Build: #${BUILD_NUMBER}
Branch: ${GIT_BRANCH}
Commit: ${GIT_COMMIT}
URL: ${BUILD_URL}

Console: ${BUILD_URL}console
                """
            )
        }
    }
}
```

---

## Pipeline Execution Model

```text
Jenkins Controller:
  1. Reads Jenkinsfile from SCM
  2. Compiles and validates Pipeline DSL
  3. Allocates agent(s) per agent directives
  4. Dispatches stages to agents
  5. Collects results, updates build status
  6. Executes post actions

Agent:
  1. Receives build instructions from controller
  2. Creates workspace
  3. Executes steps sequentially
  4. Reports step results back to controller
  5. Cleans up workspace (if configured)
```

---

## Pipeline Durability

Jenkins pipelines persist their state to disk. If Jenkins restarts mid-build:

| Durability Level | Description | Use Case |
|-----------------|-------------|----------|
| `MAX_SURVIVABILITY` | Writes state after every step | Long-running critical pipelines |
| `PERFORMANCE_OPTIMIZED` | Writes less often, faster | Default for most pipelines |
| `SURVIVABLE_NONATOMIC` | Balance of above | Medium risk tolerance |

```groovy
options {
    durabilityHint('PERFORMANCE_OPTIMIZED')
}
```

---

## Pipeline Syntax Generator

Jenkins includes a built-in snippet generator:

Navigate to: `http://jenkins.example.com/pipeline-syntax/`

Features:

- **Snippet Generator** — Generate Pipeline steps from UI form
- **Declarative Directive Generator** — Generate directives (agent, options, etc.)
- **Global Variables Reference** — All available variables
- **Online Documentation** — Context-sensitive help

---

## Best Practices

1. **Store Jenkinsfile in the root** of the repository
2. **Use Declarative Pipeline** — simpler, validated, IDE support
3. **Set `options { timeout() }`** — pipelines should not run forever
4. **Set `buildDiscarder`** — manage disk space
5. **Use `disableConcurrentBuilds()`** — for deployments especially
6. **Always use `post { always { cleanWs() }}`** — clean up after every build
7. **Use `parallel` stages** for independent steps — reduce build time
8. **Add `when { beforeAgent true }` conditions** — don't allocate agents for skipped stages
9. **Use `stash`/`unstash`** to pass files between stages on different agents
10. **Keep pipeline logic in Groovy; business logic in scripts** — Jenkinsfiles should orchestrate, not implement

---

## References

- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Pipeline Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)
- [Pipeline Snippet Generator](https://www.jenkins.io/doc/book/pipeline/getting-started/#snippet-generator)
- [Declarative Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/declarative-pipeline/)

---

## Next Section

[06 — Declarative Pipelines →](../06-declarative-pipelines/README.md)
