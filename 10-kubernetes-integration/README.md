# 10 — Kubernetes Integration

## Overview

Running Jenkins on Kubernetes is the gold standard for production CI/CD. Kubernetes provides dynamic, ephemeral build agents that scale automatically, self-heal, and make efficient use of cluster resources. This section covers Jenkins on Kubernetes from initial deployment to production-grade configurations.

---

## Objectives

- Deploy Jenkins on Kubernetes using Helm
- Configure the Kubernetes Plugin for dynamic agents
- Build pod templates for different build types
- Use persistent storage for Jenkins home
- Set up ingress with TLS
- Implement RBAC for Jenkins agents
- Deploy applications to Kubernetes from Jenkins pipelines
- Implement GitOps workflows with ArgoCD

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CLUSTER                           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    jenkins namespace                         │   │
│  │                                                              │   │
│  │  ┌─────────────────────────┐                                │   │
│  │  │   Jenkins Controller    │                                │   │
│  │  │   (StatefulSet/Deploy)  │                                │   │
│  │  │                         │                                │   │
│  │  │  Port 8080 (UI/API)     │                                │   │
│  │  │  Port 50000 (agents)    │                                │   │
│  │  │                         │                                │   │
│  │  │  PVC: jenkins-home      │                                │   │
│  │  │  (20Gi persistent)      │                                │   │
│  │  └────────────┬────────────┘                                │   │
│  │               │ Spawns agent pods                           │   │
│  │               ▼                                             │   │
│  │  ┌──────────────────────────────────────────────────┐      │   │
│  │  │  Agent Pod (ephemeral)                           │      │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │      │   │
│  │  │  │  jnlp    │  │  maven   │  │    docker    │  │      │   │
│  │  │  │ container│  │ container│  │   container  │  │      │   │
│  │  │  └──────────┘  └──────────┘  └──────────────┘  │      │   │
│  │  │  Deleted after build completes                   │      │   │
│  │  └──────────────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────────────────┐   │
│  │ Ingress  │   │  Production  │   │   Staging Namespace       │   │
│  │  (TLS)   │   │  Namespace   │   │                          │   │
│  └──────────┘   └──────────────┘   └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Deploying Jenkins on Kubernetes (Helm)

### Prerequisites

```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Install Helm (if not installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Add Helm Repository

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm search repo jenkinsci/jenkins --versions | head -5
```

### Create Jenkins Namespace and RBAC

```yaml
# jenkins-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
  labels:
    name: jenkins
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-agent-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "persistentvolumeclaims", "events"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["configmaps", "secrets", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-agent-role-binding
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
roleRef:
  kind: ClusterRole
  name: jenkins-agent-role
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f jenkins-namespace.yaml
```

### Production Helm Values

```yaml
# jenkins-production-values.yaml
controller:
  image:
    repository: jenkins/jenkins
    tag: "lts-jdk21"
    pullPolicy: IfNotPresent

  adminUser: "admin"
  adminPassword: ""  # Set via --set or external secret

  serviceType: ClusterIP
  servicePort: 8080
  targetPort: 8080
  agentListenerServiceType: ClusterIP
  agentListenerPort: 50000

  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"

  javaOpts: >-
    -Xmx3g
    -Xms1g
    -XX:+UseG1GC
    -XX:+UseStringDeduplication
    -Djenkins.install.runSetupWizard=false

  # Plugins to install
  installPlugins:
    - kubernetes:4.6.0
    - workflow-aggregator:latest
    - git:latest
    - configuration-as-code:1800.v28740ed978fb_
    - role-strategy:latest
    - pipeline-stage-view:latest
    - blueocean:latest
    - docker-workflow:latest
    - credentials-binding:latest
    - ansicolor:latest
    - timestamper:latest
    - build-timeout:latest
    - ws-cleanup:latest
    - junit:latest
    - prometheus:latest
    - slack:latest
    - email-ext:latest
    - sonar:latest

  # Jenkins Configuration as Code
  JCasC:
    enabled: true
    configScripts:
      main-config: |
        jenkins:
          systemMessage: "Jenkins on Kubernetes - Managed via JCasC"
          numExecutors: 0
          scmCheckoutRetryCount: 3
          mode: EXCLUSIVE

          globalNodeProperties:
          - envVars:
              env:
              - key: DOCKER_REGISTRY
                value: registry.example.com
              - key: CLUSTER_NAME
                value: production-cluster

        unclassified:
          location:
            url: https://jenkins.example.com
            adminAddress: jenkins@example.com

          slackNotifier:
            teamDomain: mycompany
            tokenCredentialId: slack-token

        credentials:
          system:
            domainCredentials:
            - credentials:
              - usernamePassword:
                  scope: GLOBAL
                  id: github-credentials
                  description: GitHub PAT
                  username: jenkins-bot
                  password: ${GITHUB_TOKEN}

  # Prometheus metrics
  prometheus:
    enabled: true
    serviceMonitorNamespace: monitoring
    serviceMonitorAdditionalLabels:
      release: prometheus

  # Ingress
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "50m"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hostName: jenkins.example.com
    tls:
    - secretName: jenkins-tls
      hosts:
      - jenkins.example.com

# Persistent storage
persistence:
  enabled: true
  storageClass: "standard-ssd"
  accessMode: ReadWriteOnce
  size: "50Gi"
  annotations:
    backup.kubernetes.io/deltas: "PT1H PT24H P30D"

# Agent configuration
agent:
  enabled: true
  defaultsProviderTemplate: ""
  namespace: jenkins
  podName: jenkins-agent
  customJenkinsLabels: []

  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"

  # Pod templates for different build types
  podTemplates:
    maven: |
      - name: maven
        label: maven
        serviceAccount: jenkins
        containers:
          - name: jnlp
            image: jenkins/inbound-agent:latest-jdk21
            args: '^${computer.jnlpmac} ^${computer.name}'
          - name: maven
            image: maven:3.9-eclipse-temurin-21
            command: sleep
            args: 99d
            tty: true
            resources:
              requests:
                cpu: 500m
                memory: 1Gi
              limits:
                cpu: 2000m
                memory: 4Gi
            volumeMounts:
              - name: maven-cache
                mountPath: /root/.m2
        volumes:
          - name: maven-cache
            persistentVolumeClaim:
              claimName: maven-cache

    nodejs: |
      - name: nodejs
        label: nodejs
        serviceAccount: jenkins
        containers:
          - name: jnlp
            image: jenkins/inbound-agent:latest-jdk21
            args: '^${computer.jnlpmac} ^${computer.name}'
          - name: nodejs
            image: node:20-alpine
            command: sleep
            args: 99d
            tty: true
            resources:
              requests:
                cpu: 300m
                memory: 512Mi
              limits:
                cpu: 1000m
                memory: 2Gi
            volumeMounts:
              - name: npm-cache
                mountPath: /root/.npm
        volumes:
          - name: npm-cache
            emptyDir: {}

    docker: |
      - name: docker
        label: docker
        serviceAccount: jenkins
        hostNetwork: false
        containers:
          - name: jnlp
            image: jenkins/inbound-agent:latest-jdk21
            args: '^${computer.jnlpmac} ^${computer.name}'
          - name: kaniko
            image: gcr.io/kaniko-project/executor:debug
            command: /busybox/sh
            args: '-c cat'
            tty: true
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

# Backup configuration
backup:
  enabled: true
  schedule: "0 2 * * *"

serviceAccount:
  create: true
  name: jenkins
  annotations: {}
```

### Install Jenkins

```bash
# Create secrets first (not in values file)
kubectl create secret generic jenkins-secrets \
  --from-literal=GITHUB_TOKEN='your-github-token' \
  --from-literal=admin-password='your-admin-password' \
  -n jenkins

# Install Jenkins
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --values jenkins-production-values.yaml \
  --set controller.adminPassword=$(openssl rand -base64 20) \
  --wait \
  --timeout 10m

# Get admin password
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- \
  /bin/cat /run/secrets/additional/chart-admin-password

# Port forward to access UI
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

---

## Kubernetes Plugin Configuration

### Via JCasC (Recommended)

```yaml
# JCasC configuration for Kubernetes plugin
jenkins:
  clouds:
  - kubernetes:
      name: "kubernetes"
      serverUrl: ""           # Empty = use in-cluster config
      namespace: "jenkins"
      jenkinsUrl: "http://jenkins:8080"
      jenkinsTunnel: "jenkins-agent:50000"
      containerCapStr: "10"
      requestedMemory: "512Mi"
      requestedCpu: "200m"
      templates:
      - name: "default"
        label: "linux"
        serviceAccount: "jenkins"
        containers:
        - name: "jnlp"
          image: "jenkins/inbound-agent:latest-jdk21"
          resourceRequestCpu: "100m"
          resourceRequestMemory: "256Mi"
          resourceLimitCpu: "500m"
          resourceLimitMemory: "512Mi"
        nodeSelector: ""
        hostNetwork: false
```

### Via UI

Navigate: **Manage Jenkins → Clouds → Add a new cloud → Kubernetes**

```
Kubernetes URL: (blank for in-cluster)
Kubernetes Namespace: jenkins
Jenkins URL: http://jenkins:8080
Jenkins Tunnel: jenkins-agent:50000

Pod Templates:
  Name: maven-agent
  Namespace: jenkins
  Labels: maven linux
  
  Containers:
    Name: jnlp
    Image: jenkins/inbound-agent:latest-jdk21
    
    Name: maven
    Image: maven:3.9-eclipse-temurin-21
    Command: sleep
    Args: 99d
    
  Volumes:
    PVC Volume:
      Claim Name: maven-cache
      Mount Path: /root/.m2
```

---

## Pipeline with Kubernetes Agent

### Basic Kubernetes Agent Pipeline

```groovy
pipeline {
    agent {
        kubernetes {
            label 'maven-build'
            defaultContainer 'maven'
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-agent
spec:
  serviceAccountName: jenkins
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
        memory: 4Gi
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2
  volumes:
  - name: maven-cache
    persistentVolumeClaim:
      claimName: maven-cache
  nodeSelector:
    cloud.google.com/gke-nodepool: build-pool
  tolerations:
  - key: dedicated
    operator: Equal
    value: jenkins
    effect: NoSchedule
'''
        }
    }

    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package -B --no-transfer-progress'
                }
            }
        }
    }
}
```

### Multi-Container Pipeline

```groovy
pipeline {
    agent {
        kubernetes {
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
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/sh", "-c", "cat"]
    tty: true
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker/
  - name: kubectl
    image: bitnami/kubectl:1.29
    command: ["sleep", "infinity"]
  volumes:
  - name: maven-cache
    persistentVolumeClaim:
      claimName: maven-cache
  - name: docker-config
    secret:
      secretName: registry-credentials
      items:
      - key: .dockerconfigjson
        path: config.json
'''
        }
    }

    environment {
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        IMAGE_URI = "registry.example.com/my-app:${IMAGE_TAG}"
    }

    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package -DskipTests -B --no-transfer-progress'
                }
            }
        }

        stage('Test') {
            steps {
                container('maven') {
                    sh 'mvn test -B --no-transfer-progress'
                }
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Build Image') {
            steps {
                container('kaniko') {
                    sh """
                        /kaniko/executor \
                          --context=${WORKSPACE} \
                          --dockerfile=${WORKSPACE}/Dockerfile \
                          --destination=${IMAGE_URI} \
                          --cache=true \
                          --cache-repo=registry.example.com/cache
                    """
                }
            }
        }

        stage('Deploy to Dev') {
            when { branch 'develop' }
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig-dev', variable: 'KUBECONFIG')]) {
                        sh """
                            kubectl set image deployment/my-app \
                              my-app=${IMAGE_URI} \
                              -n dev
                            kubectl rollout status deployment/my-app -n dev --timeout=5m
                        """
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when { branch 'main' }
            steps {
                input 'Deploy to production?'
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig-production', variable: 'KUBECONFIG')]) {
                        sh """
                            kubectl set image deployment/my-app \
                              my-app=${IMAGE_URI} \
                              -n production
                            kubectl rollout status deployment/my-app -n production --timeout=10m
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

## Kubernetes Manifests for Applications

### Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
  labels:
    app: my-app
    version: "${IMAGE_TAG}"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: my-app
        version: "${IMAGE_TAG}"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: my-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: my-app
        image: registry.example.com/my-app:${IMAGE_TAG}
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: JAVA_OPTS
          value: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: db-password
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 10
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
          failureThreshold: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - my-app
              topologyKey: kubernetes.io/hostname
```

---

## GitOps with ArgoCD

### Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### ArgoCD Application

```yaml
# argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/my-app-gitops.git
    targetRevision: HEAD
    path: k8s/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Jenkins + GitOps Pipeline

```groovy
stage('Update GitOps Repo') {
    when { branch 'main' }
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'github-credentials',
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_PASS'
        )]) {
            sh """
                # Clone GitOps repo
                git clone https://${GIT_USER}:${GIT_PASS}@github.com/org/my-app-gitops.git
                cd my-app-gitops

                # Update image tag
                sed -i 's|image: registry.example.com/my-app:.*|image: registry.example.com/my-app:${IMAGE_TAG}|' \
                    k8s/production/deployment.yaml

                # Commit and push
                git config user.email "jenkins@example.com"
                git config user.name "Jenkins CI"
                git add k8s/production/deployment.yaml
                git commit -m "chore: deploy my-app:${IMAGE_TAG}"
                git push origin main
            """
        }
        // ArgoCD will detect the change and auto-sync
    }
}
```

---

## Persistent Volume for Maven Cache

```yaml
# maven-cache-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: maven-cache
  namespace: jenkins
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  storageClass: nfs-storage   # Must support ReadWriteMany
```

---

## Best Practices

1. **Use ephemeral agents** — delete pods after each build (Kubernetes plugin default)
2. **Resource requests and limits** — always set to prevent node exhaustion
3. **Use node affinity** — route build pods to dedicated build node pools
4. **Cache dependencies** — use PVCs for Maven/npm caches (RWX storage class)
5. **Kaniko for rootless builds** — avoid Docker-in-Docker security risks
6. **Namespace isolation** — use separate namespaces for CI builds vs. applications
7. **RBAC principle of least privilege** — Jenkins SA should have minimal permissions
8. **Pod disruption budgets** — protect the Jenkins controller from eviction
9. **Resource quotas** — limit how many agent pods Jenkins can create
10. **Use GitOps** — Jenkins updates git repo, ArgoCD handles the actual deployment

---

## References

- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Jenkins Helm Chart](https://github.com/jenkinsci/helm-charts)
- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kaniko Documentation](https://github.com/GoogleContainerTools/kaniko)
- [Helm Documentation](https://helm.sh/docs/)

---

## Next Section

[11 — Production-Grade Jenkins →](../11-production-grade-jenkins/README.md)
