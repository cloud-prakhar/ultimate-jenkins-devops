# 00 — Local Jenkins Learning Lab

## Overview

Before writing a single pipeline you need a place to run it. This section gives you a **complete, free CI/CD environment** that runs entirely on your laptop using Docker.

No AWS account. No paid services. No credit card. Just Docker.

By the end of this section you will have three services running together:

| Service | What it is | Why we need it | URL |
|---------|-----------|----------------|-----|
| **Jenkins** | The automation server we are learning | Runs our pipelines | `http://localhost:8080` |
| **Gitea** | A self-hosted GitHub replacement | Stores our code and triggers Jenkins | `http://localhost:3000` |
| **Docker Registry** | A local image store | Saves Docker images built by Jenkins | `http://localhost:5000` |

---

## Why Three Services?

A real CI/CD system always has at least these three parts. Understanding how they connect is as important as knowing any one tool individually.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Laptop                                   │
│                                                                       │
│  You push code ──▶  Gitea (Git server)                              │
│                           │                                           │
│                           │ Webhook: "new code arrived"              │
│                           ▼                                           │
│                     Jenkins (CI server)                               │
│                           │                                           │
│                    Runs the pipeline:                                 │
│                    1. Pulls code from Gitea                           │
│                    2. Runs tests                                       │
│                    3. Builds Docker image                             │
│                           │                                           │
│                           │ docker push                               │
│                           ▼                                           │
│                  Registry (image store)                               │
│                  localhost:5000/my-app:42                            │
└─────────────────────────────────────────────────────────────────────┘
```

This mirrors exactly how GitHub + Jenkins + ECR/Harbor work in production — you are learning the real pattern, not a toy version.

---

## Objectives

- Understand the role of each tool in a CI/CD system
- Stand up a complete local CI/CD lab in under 15 minutes
- Learn to use JCasC (Configuration as Code) to manage Jenkins automatically
- Set up a Gitea repository and connect it to Jenkins
- Configure a webhook so Jenkins triggers automatically on code push

---

## Prerequisites

| Requirement | How to check | Where to get it |
|-------------|-------------|-----------------|
| Docker Desktop (Mac/Windows) or Docker Engine (Linux) | `docker version` | [docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose v2 | `docker compose version` | Included with Docker Desktop |
| 4 GB RAM available for Docker | Docker Desktop → Settings → Resources | — |
| Ports 8080, 3000, 5000, 2222 free | `ss -tlnp \| grep -E '8080\|3000\|5000\|2222'` | Stop any conflicting services |

> **Note for Linux users:** Your Docker socket (`/var/run/docker.sock`) is owned by the `docker` group. The lab runs Jenkins as root inside the container to avoid permission issues. This is intentional and documented as a lab-only shortcut — see the security note below.

---

## Step 1 — Configure Your Environment

The lab reads credentials from a `.env` file. Never commit real passwords to git.

```bash
# Navigate to this directory
cd 00-local-lab-setup

# Copy the template
cp .env.example .env
```

Open `.env` and set your preferred credentials. The defaults (`admin123`, `gitea123`) are fine for a local lab that never leaves your machine.

---

## Step 2 — Configure Docker to Trust the Local Registry

The local registry at `localhost:5000` is not TLS-secured (insecure). Docker refuses to push to insecure registries unless you explicitly allow it.

**macOS / Windows (Docker Desktop):**
1. Open Docker Desktop → Settings (gear icon) → Docker Engine
2. Add `"insecure-registries"` to the JSON config:

```json
{
  "insecure-registries": ["localhost:5000"]
}
```

3. Click **Apply & Restart**

**Linux:**

```bash
# Edit (or create) the daemon configuration
sudo nano /etc/docker/daemon.json
```

```json
{
  "insecure-registries": ["localhost:5000"]
}
```

```bash
# Apply the change
sudo systemctl restart docker
```

**Verify:**
```bash
docker info | grep -A 3 "Insecure Registries"
# Expected output: localhost:5000 should appear in the list
```

> **Why is this required?** Docker enforces TLS for registries by default — the same reason browsers enforce HTTPS. For a local learning lab we skip TLS to keep setup simple. In production, always use a TLS-secured registry.

---

## Step 3 — Build and Start the Lab

```bash
# Make sure you are in the 00-local-lab-setup directory
cd 00-local-lab-setup

# Build the custom Jenkins image and start all services
docker compose up -d --build

# Watch the startup logs (Ctrl+C to stop watching — services keep running)
docker compose logs -f
```

Jenkins takes 2–3 minutes on the first start because it is installing plugins. You will see log lines like:

```
jenkins  | Installed plugin: blueocean
jenkins  | Installed plugin: docker-workflow
jenkins  | Configuration as Code plugin initialized
```

When you see `Jenkins is fully up and running`, the lab is ready.

---

## Step 4 — Verify Jenkins

Open your browser: `http://localhost:8080`

Log in with the credentials from your `.env` file (default: `admin` / `admin123`).

You should see the Jenkins dashboard. Notice:

- **Build Queue** is empty — no jobs yet, that is expected.
- **Build Executor Status** shows 0 executors — this is correct. The controller never runs builds; agents do that. We will add an agent when we create our first pipeline.
- The system message at the top confirms JCasC is working.

**Verify credentials were configured:**
Navigate to **Manage Jenkins → Credentials → System → Global credentials**

You should see:
- `gitea-credentials` — for SCM checkouts from Gitea
- `registry-credentials` — for Docker image pushes

If these are missing, check the Jenkins startup logs for JCasC errors:

```bash
docker compose logs jenkins | grep -i "casc\|error\|exception"
```

---

## Step 5 — Set Up Gitea

Open your browser: `http://localhost:3000`

### 5a — Create the admin account

Gitea's first-run setup wizard appears. Fill it in:

```
Site Title:        Jenkins Learning Lab
Repository Root:   /data/gitea/repositories
Git User/Group:    git
Server Domain:     localhost
SSH Server Port:   2222
HTTP Port:         3000
Application URL:   http://localhost:3000
Log Path:          /data/gitea/log

Administrator Account:
  Username:   gitea-admin       (match GITEA_ADMIN_USER in .env)
  Password:   gitea123          (match GITEA_ADMIN_PASSWORD in .env)
  Email:      admin@lab.local
```

Click **Install Gitea**.

### 5b — Create a webhook user for Jenkins (optional but recommended)

For a cleaner setup, create a dedicated user for Jenkins webhooks instead of using the admin account:

1. Click your avatar → **Site Administration** → **User Accounts** → **Create User Account**

```
Username:  jenkins-bot
Email:     jenkins@lab.local
Password:  jenkins-bot-pass123
```

2. Give this user access to repos you want Jenkins to build.

For this lab, using the admin account for everything is also fine.

---

## Step 6 — Create Your First Gitea Repository

1. Click the **+** icon → **New Repository**

```
Owner:       gitea-admin
Repository:  flask-todo-api
Description: CI/CD practice project
Visibility:  Public
Initialize:  ✅ (check this — it creates a default branch)
```

2. Click **Create Repository**

You now have a Git server running locally with your own repository. This works exactly like GitHub but runs entirely on your machine.

---

## Step 7 — Clone the Repository

```bash
# Clone using HTTP (port 3000)
git clone http://localhost:3000/gitea-admin/flask-todo-api.git

# Enter credentials when prompted:
# Username: gitea-admin
# Password: gitea123

cd flask-todo-api
```

> **SSH alternative:** Gitea also supports SSH on port 2222. Add your public key in Gitea (Settings → SSH/GPG Keys) and clone with:
> `git clone ssh://git@localhost:2222/gitea-admin/flask-todo-api.git`

---

## Step 8 — Set Up a Jenkins Job

We will create the Jenkins job manually for now. In a real team you would use Job DSL to automate this — that is covered in a later section.

1. Go to Jenkins (`http://localhost:8080`)
2. Click **New Item**
3. Enter name: `flask-todo-api`
4. Select: **Pipeline**
5. Click **OK**

**Configure the pipeline:**

Under **Pipeline** → **Definition**, select: `Pipeline script from SCM`

```
SCM:                Git
Repository URL:     http://gitea:3000/gitea-admin/flask-todo-api.git
Credentials:        gitea-credentials (select from the dropdown)
Branch Specifier:   */main
Script Path:        Jenkinsfile
```

> **Why `gitea:3000` instead of `localhost:3000`?**
> Jenkins runs inside a Docker container. From inside that container, `localhost` refers to the container itself — not your laptop. The service name `gitea` is the hostname Jenkins should use to reach the Gitea container within the Docker network. From your browser, you use `localhost:3000`.

Click **Save**.

---

## Step 9 — Set Up a Webhook

A webhook makes Gitea notify Jenkins automatically whenever you push code. Without a webhook, you would have to click "Build Now" manually every time — not very CI/CD.

**In Gitea:**

1. Go to your `flask-todo-api` repository
2. Click **Settings** → **Webhooks** → **Add Webhook** → **Gitea**

```
Target URL:      http://jenkins:8080/gitea-webhook/post
HTTP Method:     POST
Content Type:    application/json
Secret:          (leave empty for now)
Trigger:         Push Events
Active:          ✅
```

3. Click **Add Webhook**
4. Click **Test Delivery** to verify it works

You should see a green checkmark. Jenkins received the test webhook and did nothing (no code changed) — that is correct.

> **How does `http://jenkins:8080` work from Gitea?** Both Jenkins and Gitea are in the same Docker network (`lab-network`). Docker automatically provides DNS so containers can reach each other by service name. Gitea uses `jenkins` as the hostname, which Docker resolves to Jenkins's container IP.

---

## Validation — Everything Working?

Run this checklist before moving to the projects:

```bash
# 1. All containers are running
docker compose ps
# Expected: jenkins, gitea, registry all show "Up"

# 2. Jenkins API responds
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/json --user admin:admin123
# Expected: 200

# 3. Gitea API responds
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/v1/version
# Expected: 200

# 4. Registry API responds
curl -s http://localhost:5000/v2/
# Expected: {} (empty JSON object — registry is healthy)

# 5. Docker can push to the local registry
docker pull hello-world
docker tag hello-world localhost:5000/hello-world:test
docker push localhost:5000/hello-world:test
# Expected: "latest: digest: sha256:..."
```

If any check fails, see the Troubleshooting section below.

---

## Understanding What You Just Built

Take a moment to appreciate what is running:

```
Your browser ──▶ http://localhost:8080 ──▶ jenkins container ──▶ jenkins-data volume
Your browser ──▶ http://localhost:3000 ──▶ gitea container   ──▶ gitea-data volume
docker push  ──▶ localhost:5000        ──▶ registry container ──▶ registry-data volume

gitea container ──▶ http://jenkins:8080 (webhook via Docker internal network)
jenkins container ──▶ http://gitea:3000 (SCM checkout via Docker internal network)
jenkins container ──▶ /var/run/docker.sock (builds Docker images using host daemon)
jenkins container ──▶ localhost:5000 (push images to registry via host port mapping)
```

The Docker socket mount is a key concept: Jenkins does not run its own Docker daemon. It connects to the **host machine's Docker daemon** through the Unix socket. This is why images built inside the Jenkins container appear in your `docker image ls` output on your laptop.

---

## Troubleshooting

### Jenkins UI not loading after startup

```bash
# Jenkins takes 2–3 minutes on first start (plugin installation)
docker compose logs jenkins --tail 30

# Look for:
# "Jenkins is fully up and running"   ← good
# "error" or "exception"              ← investigate
```

### Port already in use

```bash
# Find what is using port 8080
lsof -i :8080       # macOS/Linux
netstat -ano | findstr :8080   # Windows

# Change the port in docker-compose.yml if needed:
# ports:
#   - "9090:8080"   ← maps host 9090 to container 8080
```

### Docker socket permission denied (Linux)

```bash
# Check socket ownership
ls -la /var/run/docker.sock
# Expected: srw-rw---- 1 root docker ...

# If your user is not in the docker group:
sudo usermod -aG docker $USER
# Log out and back in for the change to take effect
```

### Webhook test fails ("Connection refused")

This means Gitea cannot reach Jenkins. Check:

1. Both containers are on the same network: `docker network inspect 00-local-lab-setup_lab-network`
2. The webhook URL uses `jenkins:8080` (not `localhost:8080`)
3. The `gitea` plugin is installed in Jenkins (check Manage Jenkins → Plugins → Installed)

### JCasC credentials not appearing

```bash
docker compose logs jenkins | grep -i "casc"
# Look for "Configuration as Code applied"
# If you see errors, check jenkins/jenkins.yaml syntax
```

---

## Cleanup

```bash
# Stop the lab (data is preserved in volumes)
docker compose down

# Stop AND delete all data (complete fresh start)
docker compose down -v

# Remove the built Jenkins image (to force a full rebuild)
docker compose down
docker rmi 00-local-lab-setup-jenkins
docker compose up -d --build
```

---

## Security Note

> **⚠️ This lab is for local learning only.**
>
> Several shortcuts were made intentionally to keep setup simple:
> - Jenkins runs as root inside the container
> - Passwords are stored in a `.env` file (not a secrets manager)
> - The Docker registry has no authentication or TLS
> - Authorization is "logged-in users can do anything"
>
> None of these are acceptable in production. The production-grade configurations are covered in:
> - [Section 11 — Production-Grade Jenkins](../11-production-grade-jenkins/)
> - [Section 12 — Security](../12-security/)

---

## Best Practices Applied Here

1. **Configuration as Code (JCasC)** — Jenkins is fully configured from `jenkins.yaml`, not by clicking through the UI. This makes the setup reproducible and version-controlled.
2. **No builds on the controller** — `numExecutors: 0` enforces this even in the lab.
3. **Named Docker volumes** — Data persists across container restarts.
4. **Credential abstraction** — Passwords live in `.env`, not hardcoded in config files.
5. **Service isolation** — Each service runs in its own container with its own responsibility.

---

## Next Step

Your lab is ready. Now let's build something real with it.

[11 — Python Flask Todo API Pipeline →](../15-real-world-projects/11-python-flask-todo-api/README.md)

Or continue reading the theory sections in order:

[01 — Jenkins Fundamentals →](../01-fundamentals/README.md)
