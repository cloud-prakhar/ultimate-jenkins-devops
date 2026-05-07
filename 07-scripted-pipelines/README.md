# 07 — Scripted Pipelines

## Overview

Scripted Pipeline uses the full power of Groovy to define Jenkins pipelines. While Declarative Pipeline covers 95% of use cases with cleaner syntax, Scripted Pipeline is essential for complex dynamic workflows, legacy systems, and advanced patterns that Declarative cannot express.

---

## Objectives

- Understand the Scripted Pipeline syntax and execution model
- Write production Scripted pipelines
- Use Groovy features: closures, maps, lists, control flow
- Dynamically generate stages at runtime
- Handle complex error handling with try/catch/finally
- Mix Scripted and Declarative approaches
- Know when to choose Scripted over Declarative

---

## Declarative vs Scripted: When to Choose

| Situation | Use |
|-----------|-----|
| Standard CI/CD pipeline | Declarative |
| Need IDE/linting support | Declarative |
| Cross-platform matrix builds | Declarative (matrix directive) |
| Dynamic stage generation | Scripted |
| Complex error handling with try/catch | Scripted (or `script {}` block in Declarative) |
| Complex conditional logic | Scripted |
| Legacy pipelines | Usually Scripted |
| Shared library internals | Usually Scripted |

---

## Basic Scripted Pipeline Structure

```groovy
node('linux') {                         // Allocate an agent

    def appName = 'my-app'
    def imageTag = "${BUILD_NUMBER}"

    try {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh 'mvn clean package -DskipTests'
        }

        stage('Test') {
            sh 'mvn test'
        }

        stage('Deploy') {
            sh "./deploy.sh ${appName} ${imageTag}"
        }

        currentBuild.result = 'SUCCESS'

    } catch (err) {
        currentBuild.result = 'FAILURE'
        throw err

    } finally {
        // Always runs
        cleanWs()
        notifySlack(currentBuild.result)
    }
}
```

---

## Groovy Fundamentals for Jenkins

### Variables and Types

```groovy
// String (def is untyped)
def name = 'jenkins'
String typedName = 'jenkins'

// Multiline string (GString supports interpolation)
def message = """
Build: ${BUILD_NUMBER}
Branch: ${GIT_BRANCH}
Status: ${currentBuild.result}
"""

// List
def environments = ['dev', 'staging', 'production']

// Map
def config = [
    appName: 'my-app',
    namespace: 'production',
    replicas: 3
]

// Access map values
echo config.appName
echo config['namespace']
```

### Control Flow

```groovy
// if/else
if (env.BRANCH_NAME == 'main') {
    sh './deploy-production.sh'
} else if (env.BRANCH_NAME.startsWith('feature/')) {
    sh './deploy-dev.sh'
} else {
    echo "No deployment for branch: ${env.BRANCH_NAME}"
}

// Switch/case
switch (params.ENVIRONMENT) {
    case 'production':
        sh './deploy-prod.sh'
        break
    case 'staging':
        sh './deploy-staging.sh'
        break
    default:
        sh './deploy-dev.sh'
}

// For loop
['service-a', 'service-b', 'service-c'].each { service ->
    stage("Deploy ${service}") {
        sh "./deploy.sh ${service}"
    }
}

// While loop
def retries = 0
def maxRetries = 3
while (retries < maxRetries) {
    try {
        sh './health-check.sh'
        break
    } catch (err) {
        retries++
        if (retries == maxRetries) throw err
        sleep 30
    }
}
```

### Closures

```groovy
// Define a reusable closure
def withDockerLogin = { String registry, String credId, Closure body ->
    withCredentials([usernamePassword(
        credentialsId: credId,
        usernameVariable: 'REGISTRY_USER',
        passwordVariable: 'REGISTRY_PASS'
    )]) {
        sh "echo '${REGISTRY_PASS}' | docker login ${registry} -u ${REGISTRY_USER} --password-stdin"
        body()
        sh "docker logout ${registry}"
    }
}

// Use the closure
node('linux') {
    stage('Push Image') {
        withDockerLogin('registry.example.com', 'registry-creds') {
            sh 'docker push registry.example.com/my-app:latest'
        }
    }
}
```

---

## Error Handling

```groovy
node('linux') {
    def buildSuccess = true

    stage('Build') {
        try {
            sh 'mvn clean package'
        } catch (err) {
            echo "Build failed: ${err.message}"
            buildSuccess = false
            currentBuild.result = 'FAILURE'
            throw err   // Re-throw to stop pipeline
        }
    }

    stage('Test') {
        try {
            sh 'mvn test'
        } catch (err) {
            // Mark as unstable, don't fail the build
            echo "Tests failed: ${err.message}"
            currentBuild.result = 'UNSTABLE'
            // Don't throw — pipeline continues
        } finally {
            // Always publish results even if tests fail
            junit 'target/surefire-reports/*.xml'
        }
    }

    stage('Report') {
        // Run regardless of test failure
        echo "Build status: ${currentBuild.result}"
    }

    // Cleanup always runs
    if (buildSuccess) {
        echo "All stages passed!"
    }
    cleanWs()
}
```

### `catchError` Step

```groovy
stage('Optional Security Scan') {
    catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
        sh 'trivy image --exit-code 1 my-app:latest'
    }
    // Pipeline continues even if security scan fails
    // Build is marked UNSTABLE instead of FAILURE
}
```

---

## Dynamic Stage Generation

One of the most powerful Scripted Pipeline features:

```groovy
def services = ['auth-service', 'payment-service', 'notification-service', 'api-gateway']
def deployStages = [:]

node('linux') {
    stage('Checkout') {
        checkout scm
    }

    // Build parallel deployment stages dynamically
    services.each { service ->
        deployStages["Deploy ${service}"] = {
            node('linux') {
                stage("Deploy ${service}") {
                    echo "Deploying: ${service}"
                    sh """
                        kubectl set image deployment/${service} \
                          ${service}=registry.example.com/${service}:${BUILD_NUMBER} \
                          -n production
                        kubectl rollout status deployment/${service} -n production
                    """
                }
            }
        }
    }

    // Execute all deployments in parallel
    parallel deployStages
}
```

### Dynamic Stages from Configuration File

```groovy
node('linux') {
    stage('Load Config') {
        checkout scm

        def config = readYaml file: 'deploy-config.yaml'
        def stages = [:]

        config.services.each { service ->
            def svcName = service.name
            def svcImage = service.image
            def svcNamespace = service.namespace

            stages["Deploy ${svcName}"] = {
                node("${service.agent ?: 'linux'}") {
                    sh """
                        helm upgrade --install ${svcName} ./charts/${svcName} \
                          --set image.tag=${BUILD_NUMBER} \
                          --namespace ${svcNamespace} \
                          --wait --timeout 5m
                    """
                }
            }
        }

        parallel stages
    }
}
```

```yaml
# deploy-config.yaml
services:
  - name: auth-service
    image: registry.example.com/auth-service
    namespace: production
    agent: linux
  - name: payment-service
    image: registry.example.com/payment-service
    namespace: production
    agent: linux-high-mem
```

---

## Multi-Node Pipelines

```groovy
def buildArtifact

node('build-agent') {
    stage('Build') {
        checkout scm
        sh 'mvn clean package -DskipTests'
        stash name: 'artifacts', includes: 'target/*.jar'
        buildArtifact = sh(script: 'ls target/*.jar', returnStdout: true).trim()
    }

    stage('Test') {
        sh 'mvn test'
        junit 'target/surefire-reports/*.xml'
    }
}

node('deploy-agent') {
    stage('Deploy') {
        unstash 'artifacts'
        echo "Deploying: ${buildArtifact}"
        sh "./deploy.sh ${buildArtifact}"
    }
}
```

---

## Complete Production Scripted Pipeline

```groovy
#!/usr/bin/env groovy

// Pipeline-level variables
def APP_NAME    = 'my-enterprise-app'
def REGISTRY    = 'registry.example.com'
def IMAGE_TAG   = "${BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'unknown'}"

// Notification helper
def notify(String status) {
    def color = status == 'SUCCESS' ? 'good' : 'danger'
    def emoji = status == 'SUCCESS' ? '✅' : '❌'
    slackSend(
        color: color,
        message: "${emoji} ${APP_NAME} #${BUILD_NUMBER}: ${status} - ${BUILD_URL}"
    )
}

// Deployment helper
def deployToEnvironment(String environment, String imageTag) {
    withCredentials([file(credentialsId: "kubeconfig-${environment}", variable: 'KUBECONFIG')]) {
        sh """
            helm upgrade --install ${APP_NAME} ./helm/${APP_NAME} \
              --namespace ${environment} \
              --set image.tag=${imageTag} \
              --set replicas=${environment == 'production' ? 3 : 1} \
              --wait \
              --timeout 10m \
              --atomic
        """
    }
}

// Main pipeline
node('linux && docker') {
    try {
        // ─── CHECKOUT ────────────────────────────────────────
        stage('Checkout') {
            checkout([
                $class: 'GitSCM',
                branches: [[name: "*/${params.BRANCH ?: 'main'}"]],
                extensions: [
                    [$class: 'CleanBeforeCheckout'],
                    [$class: 'CloneOption', noTags: false, shallow: false]
                ],
                userRemoteConfigs: [[
                    url: 'https://github.com/org/my-app.git',
                    credentialsId: 'github-credentials'
                ]]
            ])
        }

        // ─── BUILD ───────────────────────────────────────────
        stage('Build') {
            sh '''
                mvn clean package \
                  -DskipTests \
                  -Dmaven.repo.local=/root/.m2/repository \
                  -B --no-transfer-progress
            '''
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            stash name: 'build-output', includes: 'target/*.jar,Dockerfile,helm/**,scripts/**'
        }

        // ─── PARALLEL QUALITY CHECKS ─────────────────────────
        stage('Quality Gates') {
            def qualityStages = [:]

            qualityStages['Unit Tests'] = {
                sh 'mvn test -B --no-transfer-progress'
                junit 'target/surefire-reports/*.xml'
            }

            qualityStages['SonarQube Analysis'] = {
                withSonarQubeEnv('sonarqube-production') {
                    sh 'mvn sonar:sonar -B --no-transfer-progress'
                }
                // Wait for quality gate
                timeout(time: 5, unit: 'MINUTES') {
                    def qg = waitForQualityGate()
                    if (qg.status != 'OK') {
                        error "Quality gate failed: ${qg.status}"
                    }
                }
            }

            qualityStages['OWASP Dependency Check'] = {
                sh '''
                    mvn org.owasp:dependency-check-maven:check \
                      -DfailBuildOnCVSS=8 \
                      -B --no-transfer-progress
                '''
            }

            qualityStages['License Check'] = {
                sh 'mvn license:check -B'
            }

            parallel qualityStages
        }

        // ─── DOCKER BUILD ─────────────────────────────────────
        stage('Docker Build') {
            unstash 'build-output'
            sh """
                docker build \
                  --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                  --build-arg GIT_COMMIT=${GIT_COMMIT} \
                  --label "org.opencontainers.image.source=https://github.com/org/my-app" \
                  --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
                  --label "org.opencontainers.image.created=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                  --tag ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} \
                  --tag ${REGISTRY}/${APP_NAME}:latest \
                  .
            """
        }

        // ─── SECURITY SCAN ────────────────────────────────────
        stage('Container Security Scan') {
            sh """
                trivy image \
                  --exit-code 1 \
                  --severity HIGH,CRITICAL \
                  --format table \
                  ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}
            """
        }

        // ─── PUSH IMAGE ───────────────────────────────────────
        stage('Push Image') {
            withCredentials([usernamePassword(
                credentialsId: 'registry-credentials',
                usernameVariable: 'REGISTRY_USER',
                passwordVariable: 'REGISTRY_PASS'
            )]) {
                sh """
                    echo '${REGISTRY_PASS}' | docker login ${REGISTRY} \
                      -u '${REGISTRY_USER}' --password-stdin
                    docker push ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY}/${APP_NAME}:latest
                    docker logout ${REGISTRY}
                """
            }
        }

        // ─── DEPLOY DEV ───────────────────────────────────────
        if (env.BRANCH_NAME == 'develop' || env.BRANCH_NAME?.startsWith('feature/')) {
            stage('Deploy Dev') {
                deployToEnvironment('dev', IMAGE_TAG)
            }
        }

        // ─── DEPLOY STAGING ───────────────────────────────────
        if (env.BRANCH_NAME == 'main') {
            stage('Deploy Staging') {
                deployToEnvironment('staging', IMAGE_TAG)
            }

            // ─── INTEGRATION TESTS ────────────────────────────
            stage('Integration Tests') {
                sh 'mvn verify -Pintegration -B --no-transfer-progress'
                junit 'target/failsafe-reports/*.xml'
            }

            // ─── PRODUCTION GATE ──────────────────────────────
            stage('Production Approval') {
                timeout(time: 24, unit: 'HOURS') {
                    input(
                        message: "Deploy ${IMAGE_TAG} to production?",
                        ok: 'Approve',
                        submitter: 'release-managers'
                    )
                }
            }

            // ─── DEPLOY PRODUCTION ────────────────────────────
            stage('Deploy Production') {
                deployToEnvironment('production', IMAGE_TAG)

                // Tag the release
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh """
                        git config user.email "jenkins@example.com"
                        git config user.name "Jenkins"
                        git tag -a "v${BUILD_NUMBER}" -m "Release ${IMAGE_TAG}"
                        git push https://${GIT_USER}:${GIT_PASS}@github.com/org/my-app.git v${BUILD_NUMBER}
                    """
                }
            }
        }

        currentBuild.result = 'SUCCESS'

    } catch (err) {
        currentBuild.result = 'FAILURE'
        echo "Pipeline failed: ${err.message}"
        throw err

    } finally {
        // Always clean up Docker images to prevent disk bloat
        sh """
            docker rmi ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} 2>/dev/null || true
            docker rmi ${REGISTRY}/${APP_NAME}:latest 2>/dev/null || true
        """
        cleanWs()
        notify(currentBuild.result ?: 'FAILURE')
    }
}
```

---

## Scripted Pipeline Patterns

### Retry with Backoff

```groovy
def retryWithBackoff(int maxRetries, Closure body) {
    def retries = 0
    def waitSeconds = 30

    while (retries < maxRetries) {
        try {
            body()
            return  // Success — exit loop
        } catch (err) {
            retries++
            if (retries >= maxRetries) {
                throw err
            }
            echo "Attempt ${retries}/${maxRetries} failed. Waiting ${waitSeconds}s before retry..."
            sleep waitSeconds
            waitSeconds *= 2  // Exponential backoff
        }
    }
}

// Usage
retryWithBackoff(3) {
    sh './integration-test.sh'
}
```

### Lock Resources

```groovy
stage('Deploy Production') {
    // Prevent concurrent production deployments
    lock(resource: 'production-cluster', inversePrecedence: true) {
        milestone()  // Abort any older builds waiting for this lock
        sh './deploy-production.sh'
    }
}
```

### Conditional Notifications

```groovy
def sendNotification(String status, String channel = '#devops') {
    def previousStatus = currentBuild.previousBuild?.result

    if (status == 'SUCCESS' && previousStatus == 'FAILURE') {
        slackSend channel: channel, color: 'good',
                  message: "🎉 ${JOB_NAME} is FIXED! Build #${BUILD_NUMBER}"
    } else if (status == 'FAILURE') {
        slackSend channel: channel, color: 'danger',
                  message: "🔥 ${JOB_NAME} FAILED! Build #${BUILD_NUMBER} - ${BUILD_URL}"

        // Page on-call if production
        if (env.BRANCH_NAME == 'main') {
            pagerduty(resolve: false, serviceKey: PAGERDUTY_KEY,
                      incDescription: "${JOB_NAME} build failure")
        }
    }
}
```

### Read and Use Build Info

```groovy
node('linux') {
    stage('Info') {
        echo "Current Build:"
        echo "  Number: ${BUILD_NUMBER}"
        echo "  Result: ${currentBuild.result}"
        echo "  Duration: ${currentBuild.durationString}"
        echo "  URL: ${BUILD_URL}"
        echo ""

        def prevBuild = currentBuild.previousBuild
        if (prevBuild) {
            echo "Previous Build:"
            echo "  Number: ${prevBuild.number}"
            echo "  Result: ${prevBuild.result}"
            echo "  Duration: ${prevBuild.durationString}"
        }
    }
}
```

---

## Mixing Declarative and Scripted

You can embed Scripted code inside Declarative pipelines using `script {}`:

```groovy
pipeline {
    agent any

    stages {
        stage('Dynamic Logic') {
            steps {
                script {
                    // Full Groovy power here
                    def services = ['a', 'b', 'c']
                    def parallelStages = [:]

                    services.each { svc ->
                        parallelStages["Test ${svc}"] = {
                            sh "test-${svc}.sh"
                        }
                    }

                    parallel parallelStages
                }
            }
        }

        stage('Normal Declarative Stage') {
            steps {
                sh 'standard-step.sh'
            }
        }
    }
}
```

---

## Best Practices

1. **Prefer Declarative** — Use Scripted only when Declarative cannot express the logic
2. **Extract functions** — Put reusable logic in Groovy functions or shared libraries
3. **Always use try/catch/finally** — For proper error handling and cleanup
4. **Use `currentBuild.result`** explicitly — Don't rely on implicit results
5. **Stash artifacts** — Never assume the same agent for all stages
6. **Clean Docker images** — Always clean up in `finally` to prevent disk bloat
7. **Use `lock()`** for exclusive resource access — prevents concurrent deployments
8. **Add `milestone()`** — Aborts older builds when a newer build advances further
9. **Minimize controller-side Groovy** — Heavy computation should run on agents
10. **Sandbox restrictions** — Be aware of Groovy sandbox limitations (use approved APIs)

---

## Groovy Sandbox

Jenkins executes pipeline Groovy in a sandbox for security. Some operations require approval:

```
[Pipeline] Start of Pipeline
Scripts not permitted to use method groovy.lang.GroovyObject invokeMethod...
→ Go to: Manage Jenkins → In-process Script Approval
→ Approve the specific method
```

Common sandbox-restricted operations:
- `System.exit()`
- Network operations
- File system operations outside workspace
- Reflection

Use `@NonCPS` for methods that can't run in CPS (Continuation Passing Style):

```groovy
@NonCPS
def parseJson(String json) {
    new groovy.json.JsonSlurper().parseText(json)
}
```

---

## References

- [Pipeline Syntax — Scripted](https://www.jenkins.io/doc/book/pipeline/syntax/#scripted-pipeline)
- [Groovy Language Documentation](https://groovy-lang.org/documentation.html)
- [Pipeline CPS Execution](https://www.jenkins.io/doc/book/pipeline/cps-method-mismatches/)
- [Script Security Plugin](https://plugins.jenkins.io/script-security/)
- [Lockable Resources Plugin](https://plugins.jenkins.io/lockable-resources/)

---

## Next Section

[08 — Shared Libraries →](../08-shared-libraries/README.md)
