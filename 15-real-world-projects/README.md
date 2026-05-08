# 15 — Real-World Projects

## Overview

This section contains complete project implementations demonstrating Jenkins CI/CD across different technologies, deployment patterns, and complexity levels. Each project is self-contained with source code, Jenkinsfile, documentation, and deployment guides.

Projects marked **Free** require no cloud account, no paid services, and no credit card — only Docker and time.

---

## Projects Index

| # | Project | Stack | Cost | Complexity | Pattern |
|---|---------|-------|------|------------|---------|
| 11 | [**Python Flask Todo API**](./11-python-flask-todo-api/README.md) | Python, Docker, Local Registry | **Free** | **Beginner** | First CI/CD pipeline |
| 01 | [Java CI/CD Pipeline](#project-01) | Java, Maven, Docker, K8s | Cloud | Intermediate | Standard CI/CD |
| 02 | [Node.js Microservice Pipeline](#project-02) | Node.js, Docker, K8s | Cloud | Intermediate | Microservices |
| 03 | [Python ML Model Pipeline](#project-03) | Python, Docker | Cloud | Advanced | ML deployment |
| 04 | [Multi-Branch Pipeline](#project-04) | Any stack | Cloud | Intermediate | GitFlow |
| 05 | [Blue-Green Deployment](#project-05) | K8s, Helm | Cloud | Advanced | Zero-downtime |
| 06 | [Canary Deployment](#project-06) | K8s, Istio | Cloud | Advanced | Progressive delivery |
| 07 | [Infrastructure as Code Pipeline](#project-07) | Terraform, AWS | Cloud | Advanced | IaC |
| 08 | [Jenkins on Kubernetes HA](#project-08) | K8s, Helm | Cloud | Expert | Platform |
| 09 | [Backup Automation](#project-09) | Shell, AWS S3 | Cloud | Beginner | Operations |
| 10 | [Monitoring & Alerting Setup](#project-10) | Prometheus, Grafana | Cloud | Advanced | Observability |

> **Start here if you are new:** Project 11 requires only Docker and the [local lab setup](../00-local-lab-setup/README.md). Complete it before moving to the cloud-based projects.

---

## Project 01: Java CI/CD Pipeline {#project-01}

### Architecture

```
GitHub Push → Webhook → Jenkins
  → Checkout → Build → Test → SonarQube → Docker Build
  → Trivy Scan → Push to Harbor → Deploy to K8s (Dev/Staging)
  → Manual Approval → Deploy to Production → Smoke Tests
  → Slack Notification
```

### Project Structure

```
java-cicd-pipeline/
├── src/
│   ├── main/java/com/example/app/
│   │   ├── Application.java
│   │   ├── controller/
│   │   ├── service/
│   │   └── repository/
│   └── test/java/com/example/app/
├── k8s/
│   ├── dev/
│   │   └── deployment.yaml
│   ├── staging/
│   │   └── deployment.yaml
│   └── production/
│       ├── deployment.yaml
│       └── hpa.yaml
├── helm/
│   └── my-java-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       └── values-production.yaml
├── Dockerfile
├── Jenkinsfile
└── pom.xml
```

### Jenkinsfile

```groovy
@Library('jenkins-shared-library@v1.0') _

pipeline {
    agent {
        kubernetes {
            defaultContainer 'maven'
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest-jdk21
  - name: maven
    image: maven:3.9-eclipse-temurin-21
    command: ["sleep", "infinity"]
    resources:
      requests: {cpu: 500m, memory: 1Gi}
      limits: {cpu: 2000m, memory: 4Gi}
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2
  - name: docker
    image: docker:24-cli
    command: ["sleep", "infinity"]
    env:
    - name: DOCKER_HOST
      value: tcp://localhost:2375
  - name: dind
    image: docker:24-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
  - name: helm
    image: alpine/helm:3.14.0
    command: ["sleep", "infinity"]
  volumes:
  - name: maven-cache
    persistentVolumeClaim:
      claimName: maven-cache
'''
        }
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))
        disableConcurrentBuilds(abortPrevious: true)
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'production'],
            description: 'Target deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip test execution (emergency only)'
        )
        string(
            name: 'IMAGE_TAG_OVERRIDE',
            defaultValue: '',
            description: 'Override image tag (for re-deployment; leave empty for auto)'
        )
    }

    environment {
        APP_NAME     = 'java-web-app'
        REGISTRY     = 'registry.example.com'
        IMAGE_TAG    = params.IMAGE_TAG_OVERRIDE ?: "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        FULL_IMAGE   = "${REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
        SONAR_URL    = 'https://sonarqube.example.com'
        DOCKER_CREDS = credentials('registry-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                container('maven') {
                    checkout scm
                    sh '''
                        echo "Branch: ${GIT_BRANCH}"
                        echo "Commit: ${GIT_COMMIT}"
                        git log --oneline -3
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                container('maven') {
                    sh '''
                        mvn clean compile \
                          -B --no-transfer-progress \
                          -Dmaven.repo.local=/root/.m2/repository
                    '''
                }
            }
        }

        stage('Test') {
            when { expression { !params.SKIP_TESTS } }
            parallel {
                stage('Unit Tests') {
                    steps {
                        container('maven') {
                            sh '''
                                mvn test \
                                  -B --no-transfer-progress \
                                  -Dmaven.repo.local=/root/.m2/repository \
                                  -Dsurefire.reportFormat=xml
                            '''
                        }
                    }
                    post {
                        always {
                            junit 'target/surefire-reports/*.xml'
                        }
                    }
                }

                stage('Integration Tests') {
                    steps {
                        container('maven') {
                            sh '''
                                mvn verify -Pintegration \
                                  -B --no-transfer-progress \
                                  -Dmaven.repo.local=/root/.m2/repository
                            '''
                        }
                    }
                    post {
                        always {
                            junit 'target/failsafe-reports/*.xml'
                        }
                    }
                }
            }
        }

        stage('Code Quality') {
            when { expression { !params.SKIP_TESTS } }
            parallel {
                stage('SonarQube') {
                    steps {
                        container('maven') {
                            withSonarQubeEnv('sonarqube') {
                                sh '''
                                    mvn sonar:sonar \
                                      -B --no-transfer-progress \
                                      -Dsonar.projectKey=${APP_NAME} \
                                      -Dsonar.host.url=${SONAR_URL}
                                '''
                            }
                            timeout(time: 5, unit: 'MINUTES') {
                                waitForQualityGate abortPipeline: true
                            }
                        }
                    }
                }

                stage('OWASP Dependency Check') {
                    steps {
                        container('maven') {
                            sh '''
                                mvn org.owasp:dependency-check-maven:check \
                                  -DfailBuildOnCVSS=8 \
                                  -B --no-transfer-progress
                            '''
                        }
                    }
                    post {
                        always {
                            publishHTML target: [
                                allowMissing: true,
                                reportDir: 'target',
                                reportFiles: 'dependency-check-report.html',
                                reportName: 'OWASP Report'
                            ]
                        }
                    }
                }
            }
        }

        stage('Package') {
            steps {
                container('maven') {
                    sh '''
                        mvn package -DskipTests \
                          -B --no-transfer-progress \
                          -Dmaven.repo.local=/root/.m2/repository
                    '''
                }
                stash name: 'jar-artifact', includes: 'target/*.jar,Dockerfile,helm/**,k8s/**'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Docker Build') {
            when {
                anyOf { branch 'main'; branch 'develop'; branch pattern: 'release/.*' }
            }
            steps {
                container('docker') {
                    sh """
                        docker build \
                          --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                          --build-arg GIT_COMMIT=${GIT_COMMIT} \
                          --label "org.opencontainers.image.created=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                          --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
                          --label "org.opencontainers.image.source=${GIT_URL}" \
                          --tag ${FULL_IMAGE} \
                          --tag ${REGISTRY}/${APP_NAME}:latest \
                          .
                    """
                }
            }
        }

        stage('Security Scan') {
            when {
                anyOf { branch 'main'; branch 'develop'; branch pattern: 'release/.*' }
            }
            steps {
                container('docker') {
                    sh """
                        trivy image \
                          --exit-code 1 \
                          --ignore-unfixed \
                          --severity HIGH,CRITICAL \
                          --format sarif \
                          --output trivy-results.sarif \
                          ${FULL_IMAGE}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-results.sarif', allowEmptyArchive: true
                }
            }
        }

        stage('Push Image') {
            when {
                anyOf { branch 'main'; branch 'develop'; branch pattern: 'release/.*' }
            }
            steps {
                container('docker') {
                    sh """
                        echo "${DOCKER_CREDS_PSW}" | docker login ${REGISTRY} \
                          -u "${DOCKER_CREDS_USR}" --password-stdin
                        docker push ${FULL_IMAGE}
                        docker push ${REGISTRY}/${APP_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy Dev') {
            when {
                anyOf {
                    branch 'develop'
                    expression { params.ENVIRONMENT == 'dev' }
                }
            }
            steps {
                container('helm') {
                    withCredentials([file(credentialsId: 'kubeconfig-dev', variable: 'KUBECONFIG')]) {
                        sh """
                            helm upgrade --install ${APP_NAME} ./helm/${APP_NAME} \
                              --namespace dev \
                              --create-namespace \
                              --values helm/${APP_NAME}/values-dev.yaml \
                              --set image.tag=${IMAGE_TAG} \
                              --atomic --wait --timeout 10m
                        """
                    }
                }
            }
        }

        stage('Deploy Staging') {
            when {
                anyOf {
                    branch 'main'
                    expression { params.ENVIRONMENT == 'staging' }
                }
            }
            steps {
                container('helm') {
                    withCredentials([file(credentialsId: 'kubeconfig-staging', variable: 'KUBECONFIG')]) {
                        sh """
                            helm upgrade --install ${APP_NAME} ./helm/${APP_NAME} \
                              --namespace staging \
                              --values helm/${APP_NAME}/values-staging.yaml \
                              --set image.tag=${IMAGE_TAG} \
                              --atomic --wait --timeout 10m
                        """
                    }
                }
            }
        }

        stage('Smoke Tests (Staging)') {
            when { branch 'main' }
            steps {
                sh """
                    # Wait for app to be ready
                    kubectl rollout status deployment/${APP_NAME} -n staging --timeout=5m

                    # Run smoke tests
                    curl --retry 5 --retry-delay 10 --retry-connrefused \
                      https://${APP_NAME}.staging.example.com/actuator/health

                    # Run integration smoke suite
                    mvn test -Psmoke \
                      -Dapp.url=https://${APP_NAME}.staging.example.com \
                      -B --no-transfer-progress
                """
            }
        }

        stage('Production Approval') {
            when {
                anyOf {
                    branch 'main'
                    expression { params.ENVIRONMENT == 'production' }
                }
            }
            steps {
                timeout(time: 24, unit: 'HOURS') {
                    input(
                        message: """
Deploy ${APP_NAME}:${IMAGE_TAG} to PRODUCTION?

Image: ${FULL_IMAGE}
Branch: ${GIT_BRANCH}
Build: #${BUILD_NUMBER}
Commit: ${GIT_COMMIT}
                        """,
                        ok: 'Deploy to Production',
                        submitter: 'release-managers,senior-devops'
                    )
                }
            }
        }

        stage('Deploy Production') {
            when {
                anyOf {
                    branch 'main'
                    expression { params.ENVIRONMENT == 'production' }
                }
            }
            steps {
                container('helm') {
                    withCredentials([file(credentialsId: 'kubeconfig-production', variable: 'KUBECONFIG')]) {
                        sh """
                            helm upgrade --install ${APP_NAME} ./helm/${APP_NAME} \
                              --namespace production \
                              --values helm/${APP_NAME}/values-production.yaml \
                              --set image.tag=${IMAGE_TAG} \
                              --atomic --wait --timeout 15m \
                              --history-max 5
                        """
                    }
                }
            }
        }

        stage('Smoke Tests (Production)') {
            when { branch 'main' }
            steps {
                sh """
                    curl --retry 10 --retry-delay 15 --retry-connrefused \
                      https://${APP_NAME}.example.com/actuator/health
                """
            }
        }

        stage('Tag Release') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh """
                        git config user.email "jenkins@example.com"
                        git config user.name "Jenkins CI"
                        git tag -a "v${BUILD_NUMBER}" \
                          -m "Release v${BUILD_NUMBER}: ${IMAGE_TAG}"
                        git push https://${GIT_USER}:${GIT_PASS}@github.com/org/${APP_NAME}.git \
                          "v${BUILD_NUMBER}"
                    """
                }
            }
        }
    }

    post {
        always {
            container('docker') {
                sh """
                    docker rmi ${FULL_IMAGE} 2>/dev/null || true
                    docker rmi ${REGISTRY}/${APP_NAME}:latest 2>/dev/null || true
                    docker logout ${REGISTRY} 2>/dev/null || true
                """
            }
            cleanWs()
        }
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ *${APP_NAME}* v${BUILD_NUMBER} deployed to *${params.ENVIRONMENT}*\nImage: `${IMAGE_TAG}`\n<${BUILD_URL}|View Build>"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "❌ *${APP_NAME}* build #${BUILD_NUMBER} FAILED on *${GIT_BRANCH}*\n<${BUILD_URL}|View Build>"
            )
        }
    }
}
```

---

## Project 05: Blue-Green Deployment {#project-05}

### Architecture

```
Jenkins → Build → Test → Package → Push Image
  → Deploy to Green (K8s)
  → Smoke Tests on Green
  → Switch Traffic (Service selector update)
  → Monitor for 10 minutes
  → Terminate Blue (or rollback)
```

### Jenkinsfile

```groovy
pipeline {
    agent { label 'linux && kubectl' }

    environment {
        APP_NAME  = 'payment-service'
        NAMESPACE = 'production'
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
    }

    stages {
        stage('Determine Active Slot') {
            steps {
                script {
                    // Determine which slot (blue/green) is currently active
                    def currentSlot = sh(
                        script: """
                            kubectl get service ${APP_NAME} \
                              -n ${NAMESPACE} \
                              -o jsonpath='{.spec.selector.slot}' \
                              2>/dev/null || echo 'blue'
                        """,
                        returnStdout: true
                    ).trim()

                    env.ACTIVE_SLOT  = currentSlot
                    env.PASSIVE_SLOT = currentSlot == 'blue' ? 'green' : 'blue'
                    echo "Active slot: ${env.ACTIVE_SLOT}"
                    echo "Deploying to: ${env.PASSIVE_SLOT}"
                }
            }
        }

        stage('Deploy to Passive Slot') {
            steps {
                sh """
                    helm upgrade --install ${APP_NAME}-${PASSIVE_SLOT} \
                      ./helm/${APP_NAME} \
                      --namespace ${NAMESPACE} \
                      --set image.tag=${IMAGE_TAG} \
                      --set slot=${PASSIVE_SLOT} \
                      --set service.enabled=false \
                      --atomic --wait --timeout 10m
                """
            }
        }

        stage('Smoke Tests on Passive') {
            steps {
                sh """
                    # Get passive slot URL
                    PASSIVE_URL=\$(kubectl get service ${APP_NAME}-${PASSIVE_SLOT}-internal \
                      -n ${NAMESPACE} \
                      -o jsonpath='{.spec.clusterIP}')

                    curl --retry 5 --retry-delay 5 \
                      http://\${PASSIVE_URL}:8080/health

                    # Run full smoke suite against passive
                    ./scripts/smoke-test.sh http://\${PASSIVE_URL}:8080
                """
            }
        }

        stage('Switch Traffic') {
            steps {
                input "Switch traffic from ${ACTIVE_SLOT} to ${PASSIVE_SLOT}?"
                sh """
                    # Update main service selector to point to passive (new) slot
                    kubectl patch service ${APP_NAME} \
                      -n ${NAMESPACE} \
                      -p '{"spec":{"selector":{"slot":"${PASSIVE_SLOT}"}}}'

                    echo "Traffic switched to ${PASSIVE_SLOT}"
                """
            }
        }

        stage('Monitor New Deployment') {
            steps {
                // Monitor for 10 minutes — rollback if error rate spikes
                timeout(time: 10, unit: 'MINUTES') {
                    sh """
                        end=\$((SECONDS + 600))
                        while [ \$SECONDS -lt \$end ]; do
                            ERROR_RATE=\$(curl -s "http://prometheus:9090/api/v1/query" \
                              --data-urlencode 'query=rate(http_requests_total{status=~"5..",service="${APP_NAME}"}[1m])' | \
                              jq -r '.data.result[0].value[1] // "0"')

                            if [ "\$(echo "\${ERROR_RATE} > 0.05" | bc)" = "1" ]; then
                                echo "ERROR: Error rate too high: \${ERROR_RATE}"
                                exit 1
                            fi

                            echo "Error rate OK: \${ERROR_RATE} ($(( (end - SECONDS) / 60 ))m remaining)"
                            sleep 30
                        done
                    """
                }
            }
            post {
                failure {
                    // Rollback: switch traffic back to active (old) slot
                    sh """
                        echo "ROLLING BACK: switching traffic back to ${ACTIVE_SLOT}"
                        kubectl patch service ${APP_NAME} \
                          -n ${NAMESPACE} \
                          -p '{"spec":{"selector":{"slot":"${ACTIVE_SLOT}"}}}'
                    """
                    slackSend color: 'danger',
                              message: "🔄 Blue-Green rollback triggered for ${APP_NAME}"
                }
            }
        }

        stage('Terminate Old Slot') {
            steps {
                sh """
                    # Scale down old slot after successful monitoring period
                    helm upgrade ${APP_NAME}-${ACTIVE_SLOT} \
                      ./helm/${APP_NAME} \
                      --namespace ${NAMESPACE} \
                      --set replicaCount=0 \
                      --wait
                    echo "Old slot (${ACTIVE_SLOT}) scaled to 0"
                """
            }
        }
    }

    post {
        success {
            slackSend color: 'good',
                      message: "✅ Blue-Green deployment complete: ${APP_NAME} ${IMAGE_TAG} on ${PASSIVE_SLOT}"
        }
    }
}
```

---

## Project 07: Infrastructure as Code Pipeline {#project-07}

### Terraform Pipeline

```groovy
pipeline {
    agent { label 'linux && terraform' }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()  // Critical: never run Terraform concurrently
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'production'],
            description: 'Target environment'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action (destroy requires extra approval)'
        )
    }

    environment {
        TF_VAR_environment = "${params.ENVIRONMENT}"
        TF_CLI_ARGS        = "-no-color"
        TF_INPUT           = "false"
        AWS_DEFAULT_REGION = "us-east-1"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                dir("terraform/${params.ENVIRONMENT}") {
                    sh 'ls -la'
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: "aws-${params.ENVIRONMENT}"]]) {
                    dir("terraform/${params.ENVIRONMENT}") {
                        sh 'terraform init -backend=true'
                        sh 'terraform validate'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: "aws-${params.ENVIRONMENT}"]]) {
                    dir("terraform/${params.ENVIRONMENT}") {
                        sh 'terraform plan -out=tfplan -detailed-exitcode'
                        sh 'terraform show -no-color tfplan > tfplan.txt'
                        archiveArtifacts artifacts: 'tfplan.txt'
                    }
                }
            }
        }

        stage('Review Plan') {
            when { expression { params.ACTION == 'apply' || params.ACTION == 'destroy' } }
            steps {
                // Show plan and require approval before applying
                script {
                    def planOutput = readFile("terraform/${params.ENVIRONMENT}/tfplan.txt")
                    echo planOutput

                    timeout(time: 4, unit: 'HOURS') {
                        input(
                            message: "Review the Terraform plan for ${params.ENVIRONMENT}. Proceed with ${params.ACTION}?",
                            ok: params.ACTION == 'destroy' ? '⚠️ DESTROY' : 'Apply'
                        )
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: "aws-${params.ENVIRONMENT}"]]) {
                    dir("terraform/${params.ENVIRONMENT}") {
                        sh 'terraform apply -auto-approve tfplan'
                        sh 'terraform output -json > terraform-output.json'
                        archiveArtifacts artifacts: 'terraform-output.json'
                    }
                }
            }
        }

        stage('Destroy Approval') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input(
                        message: "⚠️ FINAL CONFIRMATION: Destroy ALL infrastructure in ${params.ENVIRONMENT}?",
                        ok: 'DESTROY EVERYTHING',
                        submitter: 'infrastructure-leads'
                    )
                }
            }
        }

        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: "aws-${params.ENVIRONMENT}"]]) {
                    dir("terraform/${params.ENVIRONMENT}") {
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
    }

    post {
        always { cleanWs() }
        success {
            slackSend color: 'good',
                      message: "✅ Terraform ${params.ACTION} on ${params.ENVIRONMENT} succeeded"
        }
        failure {
            slackSend color: 'danger',
                      message: "❌ Terraform ${params.ACTION} on ${params.ENVIRONMENT} FAILED - ${BUILD_URL}"
        }
    }
}
```

---

## Project 09: Jenkins Backup Automation {#project-09}

```groovy
pipeline {
    agent { label 'linux && aws' }

    triggers {
        cron('0 2 * * *')  // Daily at 2 AM
    }

    environment {
        JENKINS_HOME_DIR = '/var/jenkins_home'
        BACKUP_DIR       = '/tmp/jenkins-backups'
        S3_BUCKET        = 'my-jenkins-backups'
        S3_PREFIX        = 'daily'
        RETENTION_DAYS   = '30'
    }

    stages {
        stage('Prepare') {
            steps {
                sh '''
                    mkdir -p ${BACKUP_DIR}
                    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                    echo "BACKUP_TIMESTAMP=${TIMESTAMP}" > backup.env
                    echo "BACKUP_NAME=jenkins-${TIMESTAMP}" >> backup.env
                '''
                script {
                    def envVars = readProperties file: 'backup.env'
                    env.BACKUP_TIMESTAMP = envVars.BACKUP_TIMESTAMP
                    env.BACKUP_NAME = envVars.BACKUP_NAME
                }
            }
        }

        stage('Backup Jenkins Home') {
            steps {
                sh '''
                    echo "Starting backup: ${BACKUP_NAME}"

                    tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
                      --exclude="${JENKINS_HOME_DIR}/workspace" \
                      --exclude="${JENKINS_HOME_DIR}/builds/*/archive" \
                      --exclude="${JENKINS_HOME_DIR}/logs" \
                      --exclude="${JENKINS_HOME_DIR}/caches" \
                      --exclude="${JENKINS_HOME_DIR}/.m2" \
                      "${JENKINS_HOME_DIR}"

                    SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
                    echo "Backup size: ${SIZE}"
                '''
            }
        }

        stage('Upload to S3') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                        aws s3 cp \
                          "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
                          "s3://${S3_BUCKET}/${S3_PREFIX}/${BACKUP_NAME}.tar.gz" \
                          --storage-class STANDARD_IA

                        echo "Uploaded to: s3://${S3_BUCKET}/${S3_PREFIX}/${BACKUP_NAME}.tar.gz"
                    '''
                }
            }
        }

        stage('Verify Backup') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                        # Verify file exists in S3
                        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${BACKUP_NAME}.tar.gz"
                        echo "Backup verified in S3"
                    '''
                }
            }
        }

        stage('Cleanup Old Backups') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh '''
                        # Remove S3 backups older than RETENTION_DAYS
                        CUTOFF=$(date -d "${RETENTION_DAYS} days ago" +%Y-%m-%d)
                        echo "Removing backups older than: ${CUTOFF}"

                        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" | \
                          awk '{print $4}' | \
                          while read file; do
                            FILE_DATE=$(echo "$file" | grep -oP '\d{8}')
                            if [ ! -z "$FILE_DATE" ] && [ "$FILE_DATE" < "${CUTOFF//\-/}" ]; then
                              echo "Deleting: ${file}"
                              aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${file}"
                            fi
                          done

                        # Clean local temp
                        rm -rf ${BACKUP_DIR}
                    '''
                }
            }
        }
    }

    post {
        success {
            slackSend color: 'good',
                      message: "✅ Jenkins backup completed: ${BACKUP_NAME}"
        }
        failure {
            slackSend color: 'danger',
                      message: "❌ Jenkins backup FAILED - ${BUILD_URL}"
            emailext(
                to: 'platform@example.com',
                subject: "CRITICAL: Jenkins backup failed",
                body: "Jenkins backup job failed. Investigate immediately. ${BUILD_URL}"
            )
        }
        always { cleanWs() }
    }
}
```

---

## How to Use These Projects

1. **Clone this repository**
2. **Navigate to the project folder**
3. **Read the project README** for prerequisites
4. **Create the Jenkins job** as a Multibranch Pipeline or Pipeline from SCM
5. **Configure credentials** in Jenkins as referenced in the Jenkinsfile
6. **Run the pipeline** and review each stage
7. **Adapt** the Jenkinsfile to your organization's needs

---

## References

- [Jenkins Pipeline Examples](https://www.jenkins.io/doc/pipeline/examples/)
- [Helm Charts](https://helm.sh/docs/chart_template_guide/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)

---

## Next Section

[16 — Interview Questions →](../16-interview-questions/README.md)
