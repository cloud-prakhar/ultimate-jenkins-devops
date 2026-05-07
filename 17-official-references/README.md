# 17 — 📚 Official References

## Overview

This section catalogs authoritative references for every technology covered in this repository. Always prefer official documentation over blog posts and tutorials. Official docs are accurate, maintained, and authoritative.

---

## 🔧 Jenkins

### 📖 Core Documentation

| Resource | URL | Description |
|----------|-----|-------------|
| Jenkins User Handbook | https://www.jenkins.io/doc/book/ | Complete user guide |
| Pipeline Syntax Reference | https://www.jenkins.io/doc/book/pipeline/syntax/ | All directives and options |
| Pipeline Steps Reference | https://www.jenkins.io/doc/pipeline/steps/ | All available steps |
| Declarative Pipeline | https://www.jenkins.io/doc/book/pipeline/declarative-pipeline/ | Declarative guide |
| Shared Libraries | https://www.jenkins.io/doc/book/pipeline/shared-libraries/ | Library development |
| Security Hardening | https://www.jenkins.io/doc/book/security/ | Security configuration |
| Scaling Jenkins | https://www.jenkins.io/doc/book/scaling/ | Performance and scale |

### 🔒 Security

| Resource | URL |
|----------|-----|
| 🚨 Security Advisories | https://www.jenkins.io/security/advisories/ |
| Security Policies | https://www.jenkins.io/security/ |
| Plugin Security | https://www.jenkins.io/doc/book/security/plugin-vulnerabilities/ |

### 🔌 Plugins (Official Index)

| Resource | URL |
|----------|-----|
| Plugin Index | https://plugins.jenkins.io/ |
| ☸️ Kubernetes Plugin | https://plugins.jenkins.io/kubernetes/ |
| 🐳 Docker Workflow | https://plugins.jenkins.io/docker-workflow/ |
| ⚙️ JCasC Plugin | https://plugins.jenkins.io/configuration-as-code/ |
| 🛡️ Role Strategy | https://plugins.jenkins.io/role-strategy/ |
| 🌊 Blue Ocean | https://plugins.jenkins.io/blueocean/ |
| 🛠️ Pipeline Utility Steps | https://plugins.jenkins.io/pipeline-utility-steps/ |
| 🔑 Credentials Binding | https://plugins.jenkins.io/credentials-binding/ |
| 📊 Prometheus Metrics | https://plugins.jenkins.io/prometheus/ |
| 🔐 Vault Plugin | https://plugins.jenkins.io/hashicorp-vault-plugin/ |
| 📋 Job DSL Plugin | https://plugins.jenkins.io/job-dsl/ |
| 💬 Slack Notification | https://plugins.jenkins.io/slack/ |

### 🐙 GitHub Repositories

| Resource | URL |
|----------|-----|
| Jenkins Core | https://github.com/jenkinsci/jenkins |
| Jenkins Helm Charts | https://github.com/jenkinsci/helm-charts |
| Jenkins Docker Images | https://github.com/jenkinsci/docker |
| JenkinsPipelineUnit | https://github.com/jenkinsci/JenkinsPipelineUnit |
| Pipeline Plugin | https://github.com/jenkinsci/pipeline-plugin |

---

## 🐳 Docker

| Resource | URL | Description |
|----------|-----|-------------|
| Docker Documentation | https://docs.docker.com/ | Complete Docker docs |
| Dockerfile Reference | https://docs.docker.com/engine/reference/builder/ | All Dockerfile instructions |
| Docker Compose | https://docs.docker.com/compose/ | Multi-container applications |
| Best Practices | https://docs.docker.com/develop/develop-images/dockerfile_best-practices/ | Image optimization |
| 🔒 Docker Security | https://docs.docker.com/engine/security/ | Container security |
| Docker Hub | https://hub.docker.com/ | Public registry |
| ⚡ BuildKit | https://docs.docker.com/build/buildkit/ | Advanced build engine |
| 🔍 Docker Scout | https://docs.docker.com/scout/ | Container analysis |

---

## ☸️ Kubernetes

| Resource | URL | Description |
|----------|-----|-------------|
| Kubernetes Docs | https://kubernetes.io/docs/ | Complete K8s documentation |
| kubectl Reference | https://kubernetes.io/docs/reference/kubectl/ | CLI reference |
| 🔒 Pod Security | https://kubernetes.io/docs/concepts/security/pod-security-standards/ | Security standards |
| 🌐 Network Policies | https://kubernetes.io/docs/concepts/services-networking/network-policies/ | Network security |
| 🛡️ RBAC | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ | Access control |
| 🚀 Deployments | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ | Deployment strategies |
| ⛵ Helm Docs | https://helm.sh/docs/ | Helm package manager |
| 🗂️ Helm Hub | https://artifacthub.io/ | Helm chart repository |
| 🐙 ArgoCD | https://argo-cd.readthedocs.io/ | GitOps CD |
| 🔀 Flux | https://fluxcd.io/docs/ | GitOps CD alternative |

---

## ⚙️ DevOps & CI/CD

| Resource | URL | Description |
|----------|-----|-------------|
| 📈 DORA Research | https://dora.dev/ | DevOps metrics and research |
| 🗺️ CNCF Landscape | https://landscape.cncf.io/ | Cloud native tools map |
| 🔄 CNCF CI/CD | https://landscape.cncf.io/card-mode?category=continuous-integration-delivery | CI/CD tools |
| 12-Factor App | https://12factor.net/ | App development principles |
| 🌿 GitOps Principles | https://opengitops.dev/ | GitOps specification |
| 🛡️ OpenSSF | https://openssf.org/ | Open source security |

---

## 🔒 Security

| Resource | URL | Description |
|----------|-----|-------------|
| ⚠️ OWASP Top 10 | https://owasp.org/www-project-top-ten/ | Web security risks |
| ⚠️ OWASP CI/CD Risks | https://owasp.org/www-project-top-10-ci-cd-security-risks/ | CI/CD security risks |
| 📜 NIST SP 800-204 | https://csrc.nist.gov/publications/detail/sp/800-204/final | Microservices security |
| 🔐 HashiCorp Vault | https://developer.hashicorp.com/vault/docs | Secret management |
| ✍️ Cosign (Sigstore) | https://docs.sigstore.dev/ | Image signing |
| 🔍 Trivy | https://trivy.dev/ | Vulnerability scanner |
| 📦 Syft | https://github.com/anchore/syft | SBOM generation |
| 📋 OPA | https://www.openpolicyagent.org/ | Policy as Code |

---

## 📊 Monitoring & Observability

| Resource | URL | Description |
|----------|-----|-------------|
| 🔥 Prometheus | https://prometheus.io/docs/ | Metrics system |
| 📈 Grafana | https://grafana.com/docs/ | Visualization |
| 🚨 Alertmanager | https://prometheus.io/docs/alerting/ | Alert routing |
| 🪵 Loki | https://grafana.com/docs/loki/ | Log aggregation |
| 🔭 OpenTelemetry | https://opentelemetry.io/docs/ | Observability framework |
| 🗂️ Grafana Dashboards | https://grafana.com/grafana/dashboards/ | Pre-built dashboards |
| 🔎 PromQL | https://prometheus.io/docs/prometheus/latest/querying/basics/ | Query language |

---

## 🏗️ Infrastructure as Code

| Resource | URL | Description |
|----------|-----|-------------|
| 🌍 Terraform Docs | https://developer.hashicorp.com/terraform/docs | IaC platform |
| 📦 Terraform Registry | https://registry.terraform.io/ | Providers and modules |
| 🤖 Ansible Docs | https://docs.ansible.com/ | Configuration management |
| 🌐 Pulumi Docs | https://www.pulumi.com/docs/ | IaC with real languages |
| ☁️ AWS CDK | https://docs.aws.amazon.com/cdk/ | AWS CDK |

---

## 🔀 Source Control

| Resource | URL | Description |
|----------|-----|-------------|
| 🌳 Git Reference | https://git-scm.com/docs | Complete git reference |
| 🐙 GitHub Actions | https://docs.github.com/en/actions | GitHub CI/CD |
| 🪝 GitHub Webhooks | https://docs.github.com/en/webhooks | Webhook docs |
| 🦊 GitLab CI/CD | https://docs.gitlab.com/ee/ci/ | GitLab CI/CD |
| 📝 Conventional Commits | https://www.conventionalcommits.org/ | Commit message standard |
| 🏷️ Semantic Versioning | https://semver.org/ | Versioning standard |

---

## 📚 Books (Highly Recommended)

| Title | Authors | Why Read |
|-------|---------|----------|
| 📗 The DevOps Handbook | Gene Kim et al. | DevOps theory and practice |
| 📘 Accelerate | Nicole Forsgren et al. | Science of DevOps (DORA research) |
| 📙 Continuous Delivery | Jez Humble & David Farley | Foundational CD book |
| 📕 Site Reliability Engineering | Google SRE Team | SRE principles and practices |
| 📖 The Phoenix Project | Gene Kim et al. | DevOps as a novel (great intro) |
| ☸️ Kubernetes in Action | Marko Lukša | Deep K8s reference |
| 🐳 Docker Deep Dive | Nigel Poulton | Docker fundamentals |

---

## 🤝 Community & Learning

| Resource | URL | Description |
|----------|-----|-------------|
| 💬 Jenkins Community | https://community.jenkins.io/ | Q&A forum |
| 🐛 Jenkins JIRA | https://issues.jenkins.io/ | Bug tracking |
| 🐦 Jenkins Twitter | https://twitter.com/jenkinsci | Official announcements |
| 🎥 Jenkins YouTube | https://www.youtube.com/@jenkinscicd | Tutorials and talks |
| 💬 Kubernetes Slack | https://kubernetes.slack.com/ | Community Slack |
| 🎥 CNCF YouTube | https://www.youtube.com/c/cloudnativefdn | CNCF talks |
| 🎤 KubeCon Recordings | https://www.youtube.com/c/cloudnativefdn | Conference talks |
| 🗓️ DevOps Days | https://devopsdays.org/ | Community events |
| 🗓️ HashiConf | https://hashiconf.com/ | HashiCorp events |

---

## 🏅 Certifications

| Certification | Provider | Relevant To |
|--------------|----------|-------------|
| 🎖️ CKA (Certified Kubernetes Administrator) | CNCF/Linux Foundation | Kubernetes |
| 🎖️ CKAD (Certified K8s App Developer) | CNCF/Linux Foundation | Kubernetes |
| 🎖️ CKS (Certified K8s Security Specialist) | CNCF/Linux Foundation | K8s Security |
| 🎖️ AWS Certified DevOps Engineer | AWS | AWS CI/CD |
| 🎖️ GCP Professional DevOps Engineer | Google | GCP CI/CD |
| 🎖️ Azure DevOps Expert | Microsoft | Azure DevOps |
| 🎖️ HashiCorp Terraform Associate | HashiCorp | Terraform |
| 🎖️ CloudBees Jenkins Engineer | CloudBees | Jenkins |

---

## ⚡ Quick Command Reference

```bash
# 🔧 Jenkins CLI
java -jar jenkins-cli.jar -s http://jenkins.example.com \
  -auth admin:TOKEN <command>

# 🐳 Docker
docker build --tag myapp:latest .
docker push registry.example.com/myapp:latest
docker run --rm -it myapp:latest /bin/sh

# ☸️ kubectl
kubectl get pods -n production
kubectl describe deployment myapp -n production
kubectl rollout status deployment/myapp -n production
kubectl rollout undo deployment/myapp -n production

# ⛵ Helm
helm repo add myrepo https://charts.example.com
helm install myapp myrepo/myapp --namespace production --values values.yaml
helm upgrade myapp myrepo/myapp --set image.tag=v2.0 --namespace production
helm rollback myapp 1 --namespace production
helm history myapp --namespace production

# 🌍 Terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform destroy
terraform state list
terraform output

# 🌳 git
git log --oneline -10
git diff HEAD~1
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin --tags
```

---

> 📌 *This reference section is updated as new tools and standards emerge. Always verify you are reading the current version of official documentation.*

---

## 🎉 Repository Complete

You have reached the end of the `ultimate-jenkins-devops` learning path.

**Learning Path Completed:**

```
01 Fundamentals → 02 Installation → 03 UI → 04 Freestyle Jobs →
05 Pipelines → 06 Declarative → 07 Scripted → 08 Shared Libraries →
09 Docker → 10 Kubernetes → 11 Production → 12 Security →
13 Monitoring → 14 Troubleshooting → 15 Projects → 16 Interviews →
17 References ✅
```

**What's Next:**
- 🤝 Contribute improvements via Pull Request
- ⭐ Star the repository to support the community
- 🚀 Apply these patterns in your organization
- 📢 Share with colleagues learning Jenkins
