# 09 — Docker Integration

## Overview

Docker and Jenkins are the most widely used combination in CI/CD. This section covers every aspect of Docker integration — using Docker agents for clean builds, building production images, security scanning, multi-stage builds, registry management, and Docker Compose for testing environments.

## Module Status

| Field | Value |
| --- | --- |
| Status | 🚧 In Progress |
| Practical reference | [Local lab](../00-local-lab-setup/README.md) and [Project 01](../15-real-world-projects/01-python-flask-todo-api/README.md) |
| Migration note | This module still needs a full learner-template migration with guided exercises and validation scripts |

---

## Objectives

- Use Docker containers as Jenkins build agents
- Build production-grade Docker images in pipelines
- Implement multi-stage Docker builds
- Push images to public and private registries
- Scan Docker images for vulnerabilities
- Test with Docker Compose
- Implement image tagging strategies
- Clean up Docker resources in pipelines
- Implement rootless/secure Docker builds

---

## Prerequisites

- Docker installed on Jenkins agents
- Jenkins Docker Pipeline plugin installed
- Registry credentials configured in Jenkins

---

## Docker as a Build Agent

Using Docker containers as agents gives you clean, reproducible, isolated build environments.

### Simple Docker Agent

```groovy
pipeline {
    agent {
        docker {
            image 'maven:3.9-eclipse-temurin-21-alpine'
            label 'linux'           // Run on agents labeled 'linux'
            alwaysPull true         // Always pull latest image
        }
    }

    stages {
        stage('Build') {
            steps {
                sh 'mvn --version && mvn clean package'
            }
        }
    }
}
```

### Docker Agent with Mounted Volumes

```groovy
pipeline {
    agent {
        docker {
            image 'maven:3.9-eclipse-temurin-21'
            args '''
                -v /data/maven-cache:/root/.m2:rw
                -v /var/run/docker.sock:/var/run/docker.sock
                -e MAVEN_OPTS="-Xmx2g -XX:+UseG1GC"
                --memory 4g
                --cpus 2
            '''
        }
    }

    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package -B --no-transfer-progress'
            }
        }

        stage('Docker Build') {
            steps {
                // Docker-in-Docker via socket mount
                sh 'docker build -t my-app:${BUILD_NUMBER} .'
            }
        }
    }
}
```

### Per-Stage Docker Agent

```groovy
pipeline {
    agent none  // No global agent — each stage defines its own

    stages {
        stage('Build') {
            agent {
                docker { image 'maven:3.9-eclipse-temurin-21' }
            }
            steps {
                sh 'mvn clean package -DskipTests'
                stash name: 'jar', includes: 'target/*.jar'
            }
        }

        stage('Test') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-21'
                    args '-v /data/maven-cache:/root/.m2'
                }
            }
            steps {
                unstash 'jar'
                sh 'mvn test'
            }
            post {
                always { junit 'target/surefire-reports/*.xml' }
            }
        }

        stage('Containerize') {
            agent { label 'linux && docker' }
            steps {
                unstash 'jar'
                sh 'docker build -t my-app:${BUILD_NUMBER} .'
            }
        }
    }
}
```

---

## Building Docker Images

### Production-Grade Dockerfile (Java)

```dockerfile
# Stage 1: Build
FROM maven:3.9-eclipse-temurin-21-alpine AS builder

WORKDIR /build

# Cache dependencies separately from source
COPY pom.xml .
RUN mvn dependency:go-offline -B --no-transfer-progress

COPY src/ src/
RUN mvn clean package -DskipTests -B --no-transfer-progress

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine AS runtime

# Security: don't run as root
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

# Copy only the built artifact
COPY --from=builder /build/target/*.jar app.jar

# OCI Labels
LABEL org.opencontainers.image.title="my-app" \
      org.opencontainers.image.description="My Java Application" \
      org.opencontainers.image.vendor="My Company" \
      org.opencontainers.image.licenses="MIT"

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", "app.jar"]
```

### Production-Grade Dockerfile (Node.js)

```dockerfile
# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Runtime
FROM node:20-alpine AS runtime

RUN addgroup -g 1000 nodejs && \
    adduser -G nodejs -u 1000 -s /bin/sh -D nodeuser

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json .

USER nodeuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget -q --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/server.js"]
```

### Production-Grade Dockerfile (Python)

```dockerfile
# Stage 1: Build
FROM python:3.12-slim AS builder

WORKDIR /app

RUN pip install --upgrade pip && pip install build wheel

COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim AS runtime

RUN groupadd -g 1000 appgroup && \
    useradd -u 1000 -g appgroup -m -s /bin/bash appuser

WORKDIR /app

COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache-dir /wheels/*

COPY src/ src/
COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["python", "-m", "gunicorn", "src.app:app", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

---

## Complete Docker CI/CD Pipeline

```groovy
pipeline {
    agent { label 'linux && docker' }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        APP_NAME    = 'my-java-app'
        REGISTRY    = 'registry.example.com'
        IMAGE_TAG   = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        FULL_IMAGE  = "${REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
        DOCKER_CREDS = credentials('registry-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Application') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-21-alpine'
                    args '-v /data/m2-cache:/root/.m2'
                    reuseNode true  // Use same node as outer agent
                }
            }
            steps {
                sh 'mvn clean package -DskipTests -B --no-transfer-progress'
                stash name: 'jar', includes: 'target/*.jar'
            }
        }

        stage('Run Tests') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-21-alpine'
                    args '-v /data/m2-cache:/root/.m2'
                    reuseNode true
                }
            }
            steps {
                sh 'mvn test -B --no-transfer-progress'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                unstash 'jar'
                sh """
                    docker build \
                      --file Dockerfile \
                      --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                      --build-arg GIT_COMMIT=${GIT_COMMIT} \
                      --label "build.number=${BUILD_NUMBER}" \
                      --label "git.commit=${GIT_COMMIT}" \
                      --label "git.branch=${GIT_BRANCH}" \
                      --tag ${FULL_IMAGE} \
                      --tag ${REGISTRY}/${APP_NAME}:latest \
                      .
                """
            }
        }

        stage('Scan Image') {
            steps {
                sh """
                    trivy image \
                      --exit-code 1 \
                      --ignore-unfixed \
                      --severity HIGH,CRITICAL \
                      --format table \
                      --output trivy-results.txt \
                      ${FULL_IMAGE}
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-results.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Push Image') {
            when {
                anyOf { branch 'main'; branch 'develop' }
            }
            steps {
                sh """
                    echo "${DOCKER_CREDS_PSW}" | docker login ${REGISTRY} \
                      -u "${DOCKER_CREDS_USR}" --password-stdin
                    docker push ${FULL_IMAGE}
                    docker push ${REGISTRY}/${APP_NAME}:latest
                """
            }
        }

        stage('Sign Image') {
            when { branch 'main' }
            environment {
                COSIGN_KEY = credentials('cosign-private-key')
            }
            steps {
                sh """
                    cosign sign --key ${COSIGN_KEY} ${FULL_IMAGE}
                """
            }
        }

        stage('Generate SBOM') {
            when { branch 'main' }
            steps {
                sh """
                    syft ${FULL_IMAGE} -o spdx-json > sbom.spdx.json
                """
                archiveArtifacts artifacts: 'sbom.spdx.json'
            }
        }
    }

    post {
        always {
            // Clean up local Docker images to prevent disk bloat
            sh """
                docker rmi ${FULL_IMAGE} 2>/dev/null || true
                docker rmi ${REGISTRY}/${APP_NAME}:latest 2>/dev/null || true
                docker logout ${REGISTRY} 2>/dev/null || true
            """
            cleanWs()
        }
        success {
            echo "Image ${FULL_IMAGE} built and pushed successfully"
        }
        failure {
            slackSend color: 'danger', message: "Docker build FAILED: ${JOB_NAME} #${BUILD_NUMBER}"
        }
    }
}
```

---

## Image Tagging Strategies

```groovy
environment {
    // Strategy 1: Build number + Git SHA (recommended for traceability)
    TAG_COMMIT  = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"

    // Strategy 2: Semantic version from git tag
    TAG_SEMVER  = sh(script: 'git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0"', returnStdout: true).trim()

    // Strategy 3: Branch-based
    TAG_BRANCH  = "${GIT_BRANCH.replaceAll('[^a-zA-Z0-9._-]', '-')}-${BUILD_NUMBER}"

    // Strategy 4: Date-based
    TAG_DATE    = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()

    // Strategy 5: Semantic version from pom.xml
    TAG_MAVEN   = sh(script: "mvn help:evaluate -Dexpression=project.version -q -DforceStdout", returnStdout: true).trim()
}

stage('Tag and Push') {
    steps {
        sh """
            # Always tag with specific version for traceability
            docker tag ${REGISTRY}/${APP_NAME}:${TAG_COMMIT} \
                        ${REGISTRY}/${APP_NAME}:${TAG_COMMIT}

            # Tag as 'latest' only for main branch
            if [ "${GIT_BRANCH}" = "origin/main" ]; then
                docker tag ${REGISTRY}/${APP_NAME}:${TAG_COMMIT} \
                            ${REGISTRY}/${APP_NAME}:latest
                docker push ${REGISTRY}/${APP_NAME}:latest
            fi

            # Tag with semver if available
            docker tag ${REGISTRY}/${APP_NAME}:${TAG_COMMIT} \
                        ${REGISTRY}/${APP_NAME}:${TAG_SEMVER}
            docker push ${REGISTRY}/${APP_NAME}:${TAG_SEMVER}
        """
    }
}
```

---

## Docker Compose for Integration Testing

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=test
      - DB_URL=jdbc:postgresql://postgres:5432/testdb
      - REDIS_URL=redis://redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/actuator/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=testdb
      - POSTGRES_USER=testuser
      - POSTGRES_PASSWORD=testpassword
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U testuser -d testdb"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  test-runner:
    image: maven:3.9-eclipse-temurin-21
    volumes:
      - .:/workspace
    working_dir: /workspace
    environment:
      - APP_URL=http://app:8080
    command: mvn verify -Pintegration-tests -B
    depends_on:
      app:
        condition: service_healthy
```

**Using Docker Compose in Pipeline:**

```groovy
stage('Integration Tests') {
    steps {
        sh '''
            # Start test environment
            docker-compose -f docker-compose.test.yml up -d

            # Wait for all services to be healthy
            timeout 120 sh -c "until docker-compose -f docker-compose.test.yml ps | grep -q 'healthy'; do sleep 5; done"

            # Run tests
            docker-compose -f docker-compose.test.yml run --rm test-runner
        '''
    }
    post {
        always {
            // Always tear down test environment
            sh 'docker-compose -f docker-compose.test.yml down -v --remove-orphans'
        }
    }
}
```

---

## Private Registry Setup

### Harbor Registry

```bash
# Harbor is the enterprise-grade Docker registry
# Install with Helm
helm repo add harbor https://helm.goharbor.io
helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  --set expose.type=ingress \
  --set expose.ingress.hosts.core=harbor.example.com \
  --set externalURL=https://harbor.example.com \
  --set harborAdminPassword=your-admin-password

# Configure Jenkins credential
# ID: harbor-credentials
# Username: robot$jenkins
# Password: <robot-account-token>
```

### AWS ECR

```groovy
environment {
    AWS_REGION     = 'us-east-1'
    AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
    ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    IMAGE_URI      = "${ECR_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
}

stage('Push to ECR') {
    steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-credentials']]) {
            sh """
                aws ecr get-login-password --region ${AWS_REGION} | \
                  docker login --username AWS --password-stdin ${ECR_REGISTRY}
                docker build -t ${IMAGE_URI} .
                docker push ${IMAGE_URI}
            """
        }
    }
}
```

### Google Artifact Registry

```groovy
environment {
    GCP_PROJECT    = 'my-project-id'
    GAR_LOCATION   = 'us-central1'
    GAR_REGISTRY   = "${GAR_LOCATION}-docker.pkg.dev/${GCP_PROJECT}/my-repo"
    IMAGE_URI      = "${GAR_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
}

stage('Push to GAR') {
    steps {
        withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
            sh """
                gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
                gcloud auth configure-docker ${GAR_LOCATION}-docker.pkg.dev --quiet
                docker build -t ${IMAGE_URI} .
                docker push ${IMAGE_URI}
            """
        }
    }
}
```

---

## Security Best Practices

### 1. Non-Root Users (Always)

```dockerfile
# Create non-root user
RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app
USER app
```

### 2. Rootless Builds with Buildah

```groovy
stage('Build (Rootless)') {
    agent { label 'linux && buildah' }
    steps {
        sh """
            buildah bud \
              --format=docker \
              --tag ${FULL_IMAGE} \
              .
            buildah push ${FULL_IMAGE}
        """
    }
}
```

### 3. Rootless Builds with Kaniko

```groovy
stage('Build with Kaniko') {
    agent {
        kubernetes {
            yaml '''
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker/
  volumes:
  - name: docker-config
    secret:
      secretName: registry-credentials
      items:
      - key: .dockerconfigjson
        path: config.json
'''
        }
    }
    steps {
        container('kaniko') {
            sh """
                /kaniko/executor \
                  --context=${WORKSPACE} \
                  --dockerfile=Dockerfile \
                  --destination=${FULL_IMAGE} \
                  --cache=true \
                  --cache-repo=${REGISTRY}/cache
            """
        }
    }
}
```

### 4. Image Scanning

```groovy
stage('Scan with Trivy') {
    steps {
        sh """
            trivy image \
              --exit-code 1 \
              --ignore-unfixed \
              --severity HIGH,CRITICAL \
              --format json \
              --output trivy-report.json \
              ${FULL_IMAGE}
        """
    }
    post {
        always {
            recordIssues(
                tool: trivy(pattern: 'trivy-report.json'),
                qualityGates: [[threshold: 1, type: 'TOTAL_HIGH', unstable: true]]
            )
        }
    }
}
```

---

## Docker Cleanup

```groovy
post {
    always {
        sh '''
            # Remove build-specific images
            docker rmi ${FULL_IMAGE} 2>/dev/null || true
            docker rmi ${REGISTRY}/${APP_NAME}:latest 2>/dev/null || true

            # Remove dangling images (created during build layers)
            docker image prune -f

            # Remove stopped containers
            docker container prune -f

            # Full cleanup (WARNING: removes all unused resources)
            # docker system prune -af --volumes
        '''
    }
}
```

---

## Troubleshooting

### Docker Daemon Not Available

```bash
# Verify Docker socket permissions
ls -la /var/run/docker.sock
# Should be: srw-rw---- 1 root docker

# Add Jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Permission Denied in Container

```bash
# Error: Got permission denied while trying to connect to the Docker daemon socket
# Solution: Mount socket with correct group

docker run \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(stat -c '%g' /var/run/docker.sock) \
  my-image
```

### Image Pull Rate Limits (Docker Hub)

```bash
# Use authenticated pull to avoid rate limits
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-credentials',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    sh "echo '${DOCKER_PASS}' | docker login -u '${DOCKER_USER}' --password-stdin"
}

# Or mirror Docker Hub images to private registry
```

---

## References

- [Docker Official Documentation](https://docs.docker.com/)
- [Jenkins Docker Plugin](https://plugins.jenkins.io/docker-workflow/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Trivy — Container Scanning](https://trivy.dev/)
- [Kaniko — Rootless Build](https://github.com/GoogleContainerTools/kaniko)
- [Buildah — Rootless Build](https://buildah.io/)
- [Cosign — Image Signing](https://github.com/sigstore/cosign)
- [Harbor Registry](https://goharbor.io/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)

---

## Next Section

[10 — Kubernetes Integration →](../10-kubernetes-integration/README.md)
