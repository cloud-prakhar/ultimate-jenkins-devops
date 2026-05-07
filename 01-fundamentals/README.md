# 01 — Jenkins Fundamentals

## Overview

This section covers the foundational concepts of Jenkins and Continuous Integration/Continuous Delivery (CI/CD). Before writing a single pipeline, every DevOps engineer must deeply understand what Jenkins is, why it exists, and how it works architecturally.

---

## Objectives

By the end of this section you will:

- Understand what Jenkins is and the problems it solves
- Understand CI/CD concepts at a foundational level
- Know the Jenkins architecture (controller, agents, executors)
- Understand the Jenkins build lifecycle
- Know key Jenkins terminology
- Understand how Jenkins fits in a modern DevOps toolchain

---

## Topics Covered

| # | Topic | Description |
|---|-------|-------------|
| 1 | What is Jenkins? | History, purpose, ecosystem |
| 2 | What is CI/CD? | Concepts, benefits, stages |
| 3 | Jenkins Architecture | Controller, agents, executors |
| 4 | Jenkins Build Lifecycle | Stages of a build |
| 5 | Key Terminology | Glossary of Jenkins terms |
| 6 | Jenkins vs Alternatives | Comparison with GitHub Actions, GitLab CI, etc. |
| 7 | DevOps & CI/CD Philosophy | Where Jenkins fits |

---

## What is Jenkins?

Jenkins is an **open-source automation server** written in Java. It is one of the most widely adopted CI/CD tools in the world, with over 300,000 active installations globally.

Jenkins was originally created as **Hudson** at Sun Microsystems in 2004 by Kohsuke Kawaguchi. After Oracle acquired Sun, the community forked Hudson and renamed it Jenkins in 2011. It is now maintained by the Jenkins community under the Linux Foundation's Continuous Delivery Foundation (CDF).

### What Problems Does Jenkins Solve?

Without CI/CD automation:

```
Developer writes code → manually runs tests → manually builds artifacts
→ manually deploys → manually verifies → repeat for every change
```

With Jenkins:

```
Developer pushes code → Jenkins automatically triggers
→ builds → tests → scans → packages → deploys → notifies
```

Jenkins solves:

- **Integration Hell** — frequent, automated merges prevent large-scale conflicts
- **Slow feedback loops** — developers know within minutes if their code broke something
- **Manual error-prone deployments** — automation replaces repetitive human steps
- **Lack of visibility** — centralized pipeline visibility and history
- **Inconsistent environments** — pipelines enforce consistent build and deploy processes

---

## What is CI/CD?

### Continuous Integration (CI)

**Continuous Integration** is the practice of frequently merging developer changes into a shared repository, where automated builds and tests verify each integration.

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Commit  │───▶│  Build   │───▶│   Test   │───▶│  Report  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

Key CI principles:
- Commit to mainline frequently (at least daily)
- Every commit triggers an automated build
- Build must be fast (< 10 minutes target)
- Tests must pass before merge
- Fix broken builds immediately — they are the team's top priority

### Continuous Delivery (CD)

**Continuous Delivery** extends CI by automatically deploying every successful build to a staging environment, keeping software always in a releasable state.

```
CI Pipeline → Staging Deploy → Manual Approval Gate → Production Deploy
```

### Continuous Deployment

**Continuous Deployment** goes further — every successful build is automatically deployed to production with no manual gate.

```
CI Pipeline → Staging Deploy → Automated Tests → Auto Production Deploy
```

### CI/CD Pipeline Stages

```mermaid
flowchart LR
    A[Source Code] --> B[Build]
    B --> C[Unit Tests]
    C --> D[Code Analysis]
    D --> E[Integration Tests]
    E --> F[Security Scan]
    F --> G[Package/Publish]
    G --> H[Deploy to Dev]
    H --> I[Deploy to Staging]
    I --> J[Approval Gate]
    J --> K[Deploy to Production]
    K --> L[Monitoring]
```

---

## Jenkins Architecture

Understanding Jenkins architecture is critical for production deployments.

```
┌─────────────────────────────────────────────────────────────────┐
│                      JENKINS CONTROLLER                          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Job Config  │  │  Build Queue │  │  Plugin System       │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Build History│  │  Credentials │  │  Pipeline Engine     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│                    JENKINS_HOME (/var/jenkins_home)              │
└──────────────────────────┬──────────────────────────────────────┘
                           │  JNLP / SSH / WebSocket
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
      ┌──────────┐  ┌──────────┐  ┌──────────┐
      │  Agent 1 │  │  Agent 2 │  │  Agent 3 │
      │  (Linux) │  │ (Windows)│  │ (Docker) │
      └──────────┘  └──────────┘  └──────────┘
       Executor 1    Executor 1    Executor 1
       Executor 2    Executor 2    Executor 2
```

### Jenkins Controller (Master)

The **Jenkins Controller** is the central orchestration server. It:

- Stores all configuration (jobs, credentials, plugins)
- Schedules builds and assigns them to agents
- Manages the build queue
- Provides the web UI
- Stores build history and artifacts
- Runs the pipeline engine

> **Production Rule:** Never run builds on the controller. The controller should only orchestrate — all actual work runs on agents.

### Jenkins Agents (Nodes)

**Agents** (formerly called "slaves") are worker machines that execute build steps. They:

- Connect to the controller via SSH, JNLP, or WebSocket
- Execute the actual pipeline steps
- Can be static (permanent) or dynamic (ephemeral)
- Run one or more **executors** (concurrent build slots)

#### Agent Types

| Type | Description | Use Case |
|------|-------------|----------|
| Permanent Agent | Always-on VM or bare metal | Consistent workloads |
| Docker Agent | Container spun up per build | Isolated, reproducible builds |
| Kubernetes Agent | Pod spun up per build | Cloud-native, scalable |
| SSH Agent | Connect to remote machine via SSH | Legacy systems |
| JNLP Agent | Agent connects to controller | Agents behind firewalls |

### Executors

An **executor** is a slot for running one build at a time on an agent. An agent with 4 executors can run 4 concurrent builds.

```
Agent Machine
├── Executor 1 → Build Job A
├── Executor 2 → Build Job B
├── Executor 3 → (idle)
└── Executor 4 → Build Job C
```

> **Tip:** Set executors equal to the number of CPU cores on the agent, minus one for OS overhead.

---

## Jenkins Build Lifecycle

```
1. Trigger      → Webhook, schedule, manual, upstream job
2. Queue        → Build added to the build queue
3. Agent Select → Controller assigns build to available agent
4. Workspace    → Agent prepares the workspace
5. Checkout     → Source code pulled from SCM
6. Stages       → Pipeline stages execute sequentially/in parallel
7. Post Actions → Cleanup, notifications, artifact archiving
8. Results      → Build marked SUCCESS/FAILURE/UNSTABLE/ABORTED
```

---

## Key Jenkins Terminology

| Term | Definition |
|------|-----------|
| **Job** | A configured task that Jenkins can run |
| **Build** | A single execution of a job |
| **Pipeline** | A scripted series of stages defining CI/CD workflow |
| **Stage** | A logical grouping of steps within a pipeline |
| **Step** | A single action within a stage |
| **Agent** | A machine that executes builds |
| **Executor** | A thread/slot on an agent for running builds |
| **Workspace** | A directory on the agent where build files live |
| **Artifact** | A file produced by a build (JAR, Docker image, etc.) |
| **Upstream** | A job that triggers another job |
| **Downstream** | A job triggered by another job |
| **Trigger** | The event that starts a build |
| **SCM** | Source Control Management (Git, SVN, etc.) |
| **Plugin** | Extension that adds functionality to Jenkins |
| **Credentials** | Securely stored secrets (passwords, tokens, keys) |
| **Node** | Any machine in the Jenkins cluster (controller or agent) |
| **Label** | A tag used to route builds to specific agents |
| **JCasC** | Jenkins Configuration as Code |
| **Groovy** | The scripting language used in Jenkins pipelines |
| **DSL** | Domain-Specific Language used in Pipeline and Job DSL |

---

## Jenkins vs Alternatives

| Feature | Jenkins | GitHub Actions | GitLab CI | CircleCI | ArgoCD |
|---------|---------|---------------|-----------|----------|--------|
| Self-hosted | ✅ | Optional | Optional | Optional | ✅ |
| Cloud SaaS | ❌ | ✅ | ✅ | ✅ | ❌ |
| Free | ✅ (OSS) | ✅ (limited) | ✅ (limited) | ✅ (limited) | ✅ (OSS) |
| Plugin ecosystem | ✅ (1800+) | Growing | Growing | Limited | Limited |
| Pipeline as Code | ✅ | ✅ | ✅ | ✅ | ✅ |
| Kubernetes native | Via plugin | Partial | Partial | Partial | ✅ |
| Learning curve | High | Low | Medium | Low | Medium |
| Enterprise support | CloudBees | GitHub Enterprise | GitLab EE | Paid | Paid |
| Best for | Complex enterprise CI/CD | GitHub-native projects | GitLab users | Simple cloud CI | GitOps CD |

> **When to Choose Jenkins:**
> - You need deep customization and control
> - You have complex, multi-technology build requirements
> - You need to run entirely on-premises
> - Your organization already has Jenkins expertise
> - You need the extensive plugin ecosystem

---

## Where Jenkins Fits in a Modern DevOps Toolchain

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVOPS TOOLCHAIN                             │
│                                                                     │
│  Plan    │  Code    │  Build   │  Test    │  Release  │  Deploy    │
│          │          │          │          │           │            │
│ Jira     │ Git      │ Jenkins  │ JUnit    │ Jenkins   │ Kubernetes │
│ Confluence│ GitHub  │ Maven    │ Selenium │ Helm      │ ArgoCD     │
│ Linear   │ GitLab   │ Gradle   │ SonarQube│ Nexus     │ Terraform  │
│          │          │ Docker   │ OWASP    │ Harbor    │ Ansible    │
└─────────────────────────────────────────────────────────────────────┘
```

Jenkins sits at the **heart of the CI/CD pipeline**, orchestrating tools across every phase.

---

## Key Takeaways

1. Jenkins is a battle-tested, flexible automation server used by enterprises worldwide
2. CI/CD reduces integration risk and speeds up software delivery
3. Jenkins architecture separates orchestration (controller) from execution (agents)
4. Never run builds on the Jenkins controller in production
5. Jenkins is most powerful when combined with other DevOps tools
6. The learning curve is higher than SaaS alternatives, but the flexibility is unmatched

---

## References

- [Jenkins Official Documentation](https://www.jenkins.io/doc/)
- [Jenkins Architecture](https://www.jenkins.io/doc/book/managing/nodes/)
- [CI/CD Concepts — Atlassian](https://www.atlassian.com/continuous-delivery/principles/continuous-integration-vs-delivery-vs-deployment)
- [The DevOps Handbook](https://itrevolution.com/the-devops-handbook/)
- [Continuous Delivery — Jez Humble](https://continuousdelivery.com/)
- [CNCF CI/CD Landscape](https://landscape.cncf.io/card-mode?category=continuous-integration-delivery)

---

## Next Section

[02 — Installation →](../02-installation/README.md)
