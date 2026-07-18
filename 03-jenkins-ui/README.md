# 03 — Jenkins UI Walkthrough

## Overview

This section provides a comprehensive walkthrough of the Jenkins web interface. Understanding the UI is essential before building pipelines. Experienced users should still review the administrative sections — many engineers miss powerful configuration options.

---

## Objectives

- Navigate the Jenkins dashboard confidently
- Understand every major UI section
- Create and configure jobs through the UI
- Manage plugins, credentials, and system settings
- Use Blue Ocean for modern pipeline visualization
- Understand build history, console output, and test reports

---

## Dashboard Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│  [Jenkins Logo]  Search  [User]  [Admin]  [Logout]              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌──────────────────────────────────────────┐  │
│  │ Navigation  │  │          Dashboard / Job List            │  │
│  │             │  │                                          │  │
│  │ Dashboard   │  │  All Jobs:                               │  │
│  │ My Views    │  │  ✅ my-java-app      #42  2m ago        │  │
│  │ New Item    │  │  ❌ my-node-app      #15  5m ago        │  │
│  │ People      │  │  🔵 my-pipeline      #8   Running       │  │
│  │ Build Queue │  │                                          │  │
│  │ Build Exec  │  │  Build Queue: [empty]                    │  │
│  │             │  │  Build Executors: 2/4 busy               │  │
│  └─────────────┘  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Main Navigation

### Dashboard

The main page shows:

- **Job list** with latest build status (color-coded)
- **Build Queue** — builds waiting for an available executor
- **Build Executor Status** — which executors are running what
- **Weather icons** — build health trend (sun = stable, storm = failing)

### Build Status Colors

| Color | Meaning |
|-------|---------|
| 🔵 Blue (or Green) | Last build succeeded |
| 🔴 Red | Last build failed |
| 🟡 Yellow | Last build unstable (tests failed) |
| ⚫ Grey | Never built or disabled |
| ⏳ Animated | Build running now |

> **Note:** Jenkins traditionally uses blue for success. Install the "Green Balls" plugin for green success indicators if preferred.

---

## Creating a New Item

Navigate: **Dashboard → New Item**

### Item Types

| Type | Description | Use Case |
|------|-------------|----------|
| Freestyle project | Simple, GUI-configured job | Legacy, simple builds |
| Pipeline | Scripted or Declarative pipeline | Modern CI/CD |
| Multi-configuration project | Matrix builds | Cross-platform testing |
| Folder | Organizational container | Grouping related jobs |
| Multibranch Pipeline | Auto-creates pipeline per branch | Feature branch CI |
| Organization Folder | Scans GitHub/GitLab org | Org-wide automation |

---

## Job Configuration

For each job, navigate: **Job → Configure**

### General Tab

```text
Description: Brief job description
[ ] Discard old builds
    Keep last N builds: 10
    Keep last N days: 30
[ ] GitHub project
    Project URL: https://github.com/org/repo
[ ] This project is parameterized
    Parameter types: String, Choice, Boolean, File, etc.
[ ] Disable this project
[ ] Execute concurrent builds if necessary (generally avoid)
```

### Source Code Management

```text
● Git
  Repository URL: https://github.com/org/repo.git
  Credentials: [github-credentials]
  Branches to build: */main
  
  Additional behaviors:
  - Wipe out repository & force clone (for cleanliness)
  - Checkout to specific local branch
  - Sparse Checkout paths
```

### Build Triggers

```text
[ ] Trigger builds remotely (webhook)
    Authentication Token: [secure-random-token]

[ ] Build after other projects are built
    Projects to watch: upstream-job
    Trigger when: Stable Only

[ ] Build periodically (cron)
    Schedule: H/15 * * * *   (every 15 min)

[ ] GitHub hook trigger for GITScm polling

[ ] Poll SCM
    Schedule: H/5 * * * *   (poll every 5 min)
```

> **Production Tip:** Use webhooks (GitHub/GitLab triggers) instead of polling. Polling wastes resources and creates lag.

### Jenkins Cron Syntax

```text
# Field order: Minute Hour Day-of-Month Month Day-of-Week
# Example schedules:

H * * * *          # Once per hour (random minute to spread load)
H/15 * * * *       # Every 15 minutes
H 8 * * 1-5        # 8 AM weekdays
H 22 * * *         # Once daily at 10 PM
H H * * *          # Once per day (random hour and minute)
H H 1 * *          # Once per month (1st day)
@midnight          # Alias for H H * * *
@weekly            # Alias for H H * * 0
```

> **Tip:** Always use `H` (hash) instead of fixed minute/hour values to spread build load across agents.

### Build Environment

```text
[ ] Delete workspace before build starts
[ ] Use secret text(s) or file(s)
    Bindings:
      Secret text: MY_API_KEY → credentials-id
      Username/password: USERNAME, PASSWORD → db-credentials
[ ] Abort the build if it's stuck
    Timeout minutes: 30
    Abort type: Abort the build
[ ] Add timestamps to Console Output
[ ] Color ANSI Console Output
```

### Build Steps (Freestyle)

```text
Execute shell:
  #!/bin/bash
  set -euo pipefail
  mvn clean package -DskipTests

Invoke top-level Maven targets:
  Maven version: Maven-3.9
  Goals: clean package
  POM: pom.xml

Execute Windows batch command: (Windows agents only)
  call mvn clean package
```

### Post-build Actions

```text
Archive the artifacts:
  Files to archive: target/*.jar, target/*.war

Publish JUnit test result report:
  Test report XMLs: target/surefire-reports/*.xml

Email notification:
  Recipients: team@example.com
  Send email for every unstable build

Trigger parameterized build on other projects:
  Projects to build: downstream-deploy-job
  Parameters: ARTIFACT_VERSION=${BUILD_NUMBER}
```

---

## Manage Jenkins

Navigate: **Dashboard → Manage Jenkins**

### System Configuration

| Section | Purpose |
|---------|---------|
| System | Global settings: URL, admin email, executors |
| Tools | JDK, Maven, Git, Node.js installations |
| Plugins | Install, update, remove plugins |
| Nodes and Clouds | Add/configure agents |
| Credentials | Manage all credentials |
| Configure Global Security | Authentication, authorization |
| Manage Users | User accounts |
| System Log | System log viewer |
| Reload Configuration | Reload config from disk |

### Manage Plugins

Navigate: **Manage Jenkins → Plugins**

#### Tabs

- **Updates** — Available updates for installed plugins
- **Available plugins** — Browse/search all installable plugins
- **Installed plugins** — Manage installed plugins
- **Advanced settings** — Proxy, update site URL

```bash
# Install plugins via CLI (useful for automation)
java -jar jenkins-cli.jar \
  -s http://localhost:8080 \
  -auth admin:token \
  install-plugin git pipeline-stage-view blueocean --restart
```

### Manage Credentials

Navigate: **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

#### Credential Types

| Type | Use Case | Example |
|------|----------|---------|
| Username with password | Git, Docker, registries | GitHub user + PAT |
| Secret text | API tokens, webhook secrets | Slack token |
| Secret file | Kubeconfig, service account keys | ~/.kube/config |
| SSH Username with private key | SSH-based git, SSH agents | GitHub SSH key |
| Certificate | Client certificates | PKCS12 cert |
| Google Service Account (via plugin) | GCP credentials | GCP SA JSON |

#### Credential Scopes

| Scope | Visibility |
|-------|-----------|
| Global | All jobs on this Jenkins instance |
| System | Jenkins system processes only |
| Folder | Only jobs within a specific folder |

---

## Blue Ocean UI

Blue Ocean is Jenkins' modern pipeline visualization interface.

Navigate: **Dashboard → Open Blue Ocean** (if installed)

### Features

- **Visual pipeline editor** — Drag-and-drop pipeline creation
- **Pipeline visualization** — See stage-by-stage pipeline progress
- **Branch and PR views** — Multi-branch pipeline status per branch
- **Test results** — Visual test result integration
- **Artifacts** — Easy artifact browsing

```text
Pipeline: my-java-app
Branch: main  |  Build #42  |  Duration: 4m 23s  |  ✅ Success

[Checkout] ──── [Build] ──── [Test] ──── [Docker Build] ──── [Deploy]
  0:12           1:45         1:03           0:45               0:38
  ✅             ✅           ✅             ✅                 ✅
```

### Stage View

In the classic UI, the Stage View plugin shows:

```text
Stage View:
         Checkout   Build    Test     Docker   Deploy
Build 42  ✅ 12s   ✅ 1m45  ✅ 1m3   ✅ 45s  ✅ 38s
Build 41  ✅ 11s   ✅ 1m52  ❌ FAIL  -        -
Build 40  ✅ 10s   ✅ 1m39  ✅ 58s  ✅ 42s  ✅ 36s
```

---

## Console Output

The console output is your primary debugging tool. Navigate: **Build → Console Output**

```text
Started by user Admin
Running in Durability level: MAX_SURVIVABILITY
[Pipeline] Start of Pipeline
[Pipeline] node
Running on agent-01 in /var/jenkins_home/workspace/my-app
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Checkout)
[Pipeline] checkout
Cloning repository https://github.com/org/repo.git
 > git init /var/jenkins_home/workspace/my-app
 > git fetch --tags --depth=1 origin +refs/heads/main
 > git checkout main
Commit message: "feat: add payment service"
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Build)
[Pipeline] sh
+ mvn clean package -DskipTests
[INFO] BUILD SUCCESS
[INFO] Total time: 45.123 s
[Pipeline] }
...
Finished: SUCCESS
```

### Console Output Tips

```bash
# Raw console log accessible at:
http://jenkins.example.com/job/my-app/42/consoleText

# Download log via API
curl -s http://jenkins.example.com/job/my-app/42/consoleText \
  --user admin:token > build-42.log

# Search for specific patterns
grep -i "error\|exception\|failed" build-42.log
```

---

## Build History

Navigate: **Job → Build History** (left sidebar)

```text
Build History:
#42  ✅  May 7 2026  4m 23s  main
#41  ❌  May 7 2026  2m 11s  feature/payment
#40  ✅  May 6 2026  4m 18s  main
#39  ✅  May 6 2026  4m 05s  main
...
```

Each build entry links to:

- Console Output
- Parameters used
- Changes (Git commits)
- Test results
- Artifacts
- Pipeline visualization

---

## Managing Nodes (Agents)

Navigate: **Manage Jenkins → Nodes and Clouds**

### Adding a Permanent Agent

```text
Name: linux-agent-01
Description: Ubuntu 22.04 build agent
# of executors: 4
Remote root directory: /var/jenkins/agent
Labels: linux ubuntu docker
Usage: Use this node as much as possible
Launch method: Launch agent via SSH
  Host: 192.168.1.100
  Credentials: agent-ssh-key
  Host Key Verification: Known hosts file
```

### Node Monitoring

```text
Node Status Dashboard:
  jenkins-controller  ✅  0/0 executors  (controller, no builds)
  linux-agent-01      ✅  2/4 executors  Ubuntu 22.04
  linux-agent-02      ✅  0/4 executors  Ubuntu 22.04
  windows-agent-01    ❌  Offline        Windows Server 2022
```

---

## Jenkins Security UI

Navigate: **Manage Jenkins → Security**

### Security Realm

```text
● Jenkins' own user database
  [ ] Allow users to sign up (disable in production)

○ LDAP
  Server: ldap://ldap.company.com
  Root DN: dc=company,dc=com
  User search filter: uid={0}

○ Active Directory

○ GitHub Authentication Plugin
```

### Authorization

```text
○ Anyone can do anything (NEVER in production)
○ Legacy mode
● Role-Based Strategy (recommended)
  → Configure in Manage Jenkins → Manage and Assign Roles
○ Matrix-based security
○ Project-based Matrix Authorization
```

### Role-Based Authorization Configuration

Navigate: **Manage Jenkins → Manage and Assign Roles**

```text
Global Roles:
  Role: admin
    Administer: ✅
    Read: ✅
    
  Role: developer
    Build: ✅
    Read: ✅
    Workspace: ✅
    
  Role: viewer
    Read: ✅

Project Roles:
  Role: project-alpha-dev
    Pattern: project-alpha-.*
    Build: ✅, Read: ✅, Configure: ✅
    
  Role: project-alpha-viewer
    Pattern: project-alpha-.*
    Read: ✅
```

---

## Views

Views let you organize jobs by project, team, or status.

Navigate: **Dashboard → + (New View)**

### View Types

```text
List View:
  Name: Team Alpha
  Jobs: Include jobs matching regex: alpha-.*
  Columns: Status, Job Name, Last Success, Last Failure, Last Duration

My View:
  Automatically shows jobs the current user has recently built

Build Monitor View (plugin):
  Full-screen dashboard for wall displays
```

---

## Jenkins API

Jenkins exposes a REST API for automation.

```bash
# Base URL format
http://jenkins.example.com/[job/JOB_NAME]/api/json

# Get all jobs
curl -s http://jenkins.example.com/api/json?tree=jobs[name,color] \
  --user admin:TOKEN | python3 -m json.tool

# Trigger a build
curl -X POST http://jenkins.example.com/job/my-app/build \
  --user admin:TOKEN

# Trigger with parameters
curl -X POST \
  http://jenkins.example.com/job/my-app/buildWithParameters \
  --user admin:TOKEN \
  --data-urlencode "BRANCH=feature/my-feature" \
  --data-urlencode "ENVIRONMENT=staging"

# Get build status
curl -s http://jenkins.example.com/job/my-app/lastBuild/api/json \
  --user admin:TOKEN | python3 -m json.tool

# Get console output
curl -s http://jenkins.example.com/job/my-app/42/consoleText \
  --user admin:TOKEN

# Stop a running build
curl -X POST http://jenkins.example.com/job/my-app/42/stop \
  --user admin:TOKEN
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `/` | Focus search bar |
| `?` | Show keyboard shortcuts |
| `Ctrl+F` | Browser find in console output |

---

## Best Practices

1. **Use folders** to organize jobs by team or project — avoid a flat job list
2. **Configure job descriptions** — future you will thank you
3. **Set build history limits** — keep last 10-20 builds to save disk space
4. **Never configure via UI alone** — back up config with JCasC or Job DSL
5. **Use Role-Based Authorization** — never leave authorization as "Anyone can do anything"
6. **Monitor executor utilization** — idle executors waste money, saturated ones slow builds
7. **Use the Build Monitor plugin** for team dashboards
8. **Export configurations** before major changes

---

## References

- [Jenkins User Handbook](https://www.jenkins.io/doc/book/)
- [Blue Ocean Documentation](https://www.jenkins.io/doc/book/blueocean/)
- [Jenkins Remote Access API](https://www.jenkins.io/doc/book/using/remote-access-api/)
- [Role-Based Authorization Plugin](https://plugins.jenkins.io/role-strategy/)

---

## Next Section

[04 — Freestyle Jobs →](../04-freestyle-jobs/README.md)
