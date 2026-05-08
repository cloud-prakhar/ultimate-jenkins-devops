# Project 11 — Python Flask Todo API CI/CD Pipeline

## Overview

This is the first complete, zero-cost project in this repository. You will build a full CI/CD pipeline for a real Python web API — from writing code on your laptop to having a Docker image stored in your local registry, all automated by Jenkins.

**Cost:** Free. Everything runs on your laptop.
**Prerequisites:** Complete the [Local Lab Setup](../../00-local-lab-setup/README.md) first.

---

## What You Will Build

A CI/CD pipeline that automatically runs on every `git push`:

```
You push code to Gitea
        │
        │  Webhook (instant notification)
        ▼
Jenkins starts the pipeline
        │
        ├── [Checkout]      Pull latest code from Gitea
        ├── [Install]       Install Python dependencies
        ├── [Lint]          Check code style with flake8
        ├── [Format]        Check formatting with black
        ├── [Security]      Scan for vulnerabilities with bandit
        ├── [Tests]         Run 30+ tests, enforce 80% coverage
        │
        │  (only if all tests pass AND branch is main/develop)
        │
        ├── [Docker Build]  Build a production Docker image
        └── [Push]          Store the image in localhost:5000
```

If anything fails, the pipeline stops. No broken code ever becomes a Docker image.

---

## Objectives

By completing this project you will:

- Understand WHY each CI/CD stage exists (not just how to write it)
- Run a full CI/CD pipeline for a Python application entirely for free
- See how Jenkins uses Docker containers as build environments (no Python needed on the host)
- Understand `stash` / `unstash` — how Jenkins passes files between stages
- Know how the Gitea webhook → Jenkins trigger flow works end to end
- Understand the difference between CI (quality gates) and CD (image publishing)
- Read and interpret Jenkins test result reports
- Understand multi-stage Docker builds

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Local lab running | [00-local-lab-setup](../../00-local-lab-setup/README.md) — Jenkins + Gitea + Registry |
| Git installed | `git --version` |
| Docker configured | `localhost:5000` in insecure-registries (covered in lab setup) |
| Section 05–06 read | Pipeline fundamentals — understand what a Jenkinsfile is |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Stage: Code Quality & Tests                                         │
│  Agent: python:3.12-slim (Docker container)                          │
│                                                                       │
│   Checkout → Install → Lint → Format → Security → Tests             │
│                                                      │               │
│                                               stash 'build-source'   │
└──────────────────────────────────────────────────────┼──────────────┘
                                                       │
┌──────────────────────────────────────────────────────┼──────────────┐
│  Stage: Docker Build & Push (main/develop only)      │               │
│  Agent: docker:26-cli (Docker container)             │               │
│                                                       │               │
│                                              unstash 'build-source'  │
│                                                       │               │
│                    Docker Build → Push to localhost:5000             │
└─────────────────────────────────────────────────────────────────────┘
```

**Key concepts visible in this architecture:**

- **Per-stage agents**: Each group runs in a different container. Python stage uses `python:3.12-slim`. Docker stage uses `docker:26-cli`. Neither container has both tools — they each have exactly what they need.
- **`stash` / `unstash`**: The mechanism that transfers files between containers. Without it, the Docker stage would have no source code to build from.
- **Conditional execution**: The Docker stage only runs on `main` and `develop` branches. Feature branches get quality checks but do not produce images.

---

## The Application

A simple RESTful API for managing todo items. The API has these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check — is the app alive? |
| `GET` | `/todos` | List all todos |
| `POST` | `/todos` | Create a new todo |
| `GET` | `/todos/<id>` | Get a specific todo |
| `PUT` | `/todos/<id>` | Update a todo (partial update) |
| `DELETE` | `/todos/<id>` | Delete a todo |

The app uses an in-memory store — no database setup needed. This keeps the focus on CI/CD, not on database configuration.

---

## Understanding Each Pipeline Stage

This section explains not just WHAT each stage does but WHY it exists and what happens if you skip it.

---

### Stage 1: Checkout

```groovy
stage('Checkout') {
    steps {
        checkout scm
    }
}
```

**What it does:** Pulls the latest code from Gitea into the build container's workspace.

**Why it must always be first:** Every other stage operates on the source code. Without checkout, there is nothing to lint, test, or build.

**What `checkout scm` means:** `scm` (Source Control Management) refers to the repository configured in the Jenkins job. Jenkins knows the URL and credentials from the job configuration — you do not hardcode them in the Jenkinsfile. This is the right approach: the Jenkinsfile stays portable across organizations.

---

### Stage 2: Install Dependencies

```groovy
stage('Install Dependencies') {
    steps {
        sh 'pip install -r requirements.txt -r requirements-dev.txt --quiet'
    }
}
```

**What it does:** Installs Flask, pytest, flake8, black, and bandit inside the Python container.

**Why separate runtime and dev dependencies?**
`requirements.txt` contains what the app needs to run (`flask`, `gunicorn`).
`requirements-dev.txt` contains what the CI pipeline needs (`pytest`, `flake8`, etc.).
The production Docker image only installs `requirements.txt`. This keeps the image smaller and reduces the attack surface — test tools have no business being in production.

**The pip cache:** The `-v /tmp/pip-cache:/root/.cache/pip` Docker argument mounts a directory from the host into the container. pip's download cache is stored there. On the second build, packages are read from disk instead of downloaded from PyPI — builds run faster.

---

### Stage 3: Lint (flake8)

```groovy
stage('Lint') {
    steps {
        sh 'flake8 app/ tests/'
    }
}
```

**What it does:** Checks for Python style violations and obvious errors.

**What does flake8 catch?**
- `E501`: line too long
- `F401`: imported module never used
- `F821`: undefined name
- `E711`: comparison to `None` using `==` instead of `is`
- And 100+ more rules from PEP 8

**Why enforce style in CI?** A human reviewer should spend their time thinking about logic, not arguing about trailing whitespace. Automated style enforcement means style is checked consistently on every commit, for free, without discussion.

**Configuration:** Configured in `setup.cfg` under `[flake8]`. The max line length is set to 120 to match black's default — if they use different lengths, they fight each other.

**If this fails locally:**
```bash
flake8 app/ tests/
# Fix each reported violation, then push again
```

---

### Stage 4: Format Check (black)

```groovy
stage('Format Check') {
    steps {
        sh 'black --check app/ tests/'
    }
}
```

**What it does:** Verifies that all code is formatted according to black's rules. `--check` mode does NOT modify files — it only reports differences.

**Why black?** Black is intentionally opinionated and has almost no configuration options. This eliminates formatting debates entirely. Teams using black never discuss "should this be on one line or two?" — black decides, and CI enforces it.

**If this fails locally:**
```bash
# Let black fix the formatting (this modifies your files)
black app/ tests/

# Review the changes, commit, and push
git diff
git add -p
git commit -m "style: apply black formatting"
git push
```

---

### Stage 5: Security Scan (bandit)

```groovy
stage('Security Scan') {
    steps {
        sh '''
            bandit -r app/ --severity-level medium -f txt -o bandit-report.txt || true
            cat bandit-report.txt
        '''
    }
    post {
        always {
            archiveArtifacts artifacts: 'bandit-report.txt', allowEmptyArchive: true
        }
    }
}
```

**What it does:** Scans Python code for common security vulnerabilities.

**Examples of what bandit catches:**
- Hardcoded passwords: `password = "admin123"` in code
- Weak random: using `random` instead of `secrets` for security-sensitive values
- Shell injection: unsafe use of `subprocess` with user input
- SQL injection patterns
- Use of `pickle` (unsafe deserialization)

**Why `|| true`?** This stage is set to informational mode for learners — it shows findings but does not fail the build. In a production pipeline you would remove `|| true` and let bandit fail the build on high-severity issues. See the Extending section below.

**The `archiveArtifacts` step:** After the build finishes, you can download `bandit-report.txt` from the Jenkins build page under **Build Artifacts**. Archived artifacts survive workspace cleanup (`cleanWs()`).

---

### Stage 6: Unit Tests (pytest)

```groovy
stage('Unit Tests') {
    steps {
        sh '''
            pytest tests/ \
                --junitxml=test-results/junit.xml \
                --cov=app \
                --cov-report=term-missing \
                --cov-fail-under=80 \
                -v
        '''
    }
    post {
        always {
            junit 'test-results/junit.xml'
        }
    }
}
```

**What it does:** Runs all 30+ tests and enforces 80% code coverage.

**The `--junitxml` flag:** Creates a standard XML report that Jenkins's JUnit plugin can parse. Jenkins shows:
- Which tests passed and failed
- How long each test took
- Test result history across builds (did this test start failing on build #15?)

**The `--cov-fail-under=80` flag:** If code coverage falls below 80%, pytest exits with a non-zero code and the stage fails. This enforces that new features come with tests. Without this, developers can add untested code and the pipeline happily continues.

**The `post { always { junit ... } }` block:** Notice this runs `always`, not just on success. This is deliberate: if tests fail, we still want Jenkins to parse the test report and show exactly WHICH tests failed. If we only published results on success, we would lose this information precisely when we need it most.

---

### Stage 7: Docker Build (main/develop only)

```groovy
stage('Docker Build') {
    steps {
        unstash 'build-source'
        sh """
            docker build \
                --tag ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} \
                --tag ${REGISTRY}/${APP_NAME}:latest \
                .
        """
    }
}
```

**What it does:** Builds the production Docker image using the `Dockerfile` in the project root.

**Why does this stage use a different agent?** The Python container does not have Docker CLI. The Docker CLI container does not have Python. This is separation of concerns. The `unstash 'build-source'` brings the source code (stashed by the previous stage group) into this container's workspace.

**Two tags per build:**
- `localhost:5000/flask-todo-api:42` — the specific build (immutable, never changes)
- `localhost:5000/flask-todo-api:latest` — the most recent successful build

In production, you would also tag with the git commit SHA for full traceability.

---

### Stage 8: Push to Registry (main/develop only)

```groovy
stage('Push to Registry') {
    steps {
        sh """
            docker push ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}
            docker push ${REGISTRY}/${APP_NAME}:latest
        """
    }
}
```

**What it does:** Uploads the Docker image to the local registry at `localhost:5000`.

**Why push to a registry?** The registry is the hand-off point between CI (building) and CD (deploying). A deployment system does not need the source code or the pipeline — it just pulls the image from the registry by tag. This decoupling is fundamental to CI/CD.

**Why the `always` cleanup in `post`?**

```groovy
post {
    always {
        sh "docker rmi ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} 2>/dev/null || true"
    }
}
```

After pushing, the image is safely stored in the registry. The local copy on the build agent is just a cache — it will only grow and fill disk space. Cleaning up after every build is a production discipline.

---

## Step-by-Step Lab

### Step 1 — Get the project code

```bash
# Clone the repository you already have set up in Gitea
# (replace with your actual Gitea URL and repo name)
git clone http://localhost:3000/gitea-admin/flask-todo-api.git
cd flask-todo-api
```

### Step 2 — Copy this project's files into it

```bash
# From the ultimate-jenkins-devops repo, copy this project's files:
cp -r \
  /path/to/ultimate-jenkins-devops/15-real-world-projects/11-python-flask-todo-api/. \
  .

# Or clone ultimate-jenkins-devops and copy manually
```

Commit and push:

```bash
git add .
git commit -m "feat: add Flask Todo API with CI/CD pipeline"
git push origin main
```

### Step 3 — Watch Jenkins trigger automatically

1. Go to Jenkins: `http://localhost:8080`
2. Click on the `flask-todo-api` job
3. A build should start within seconds (triggered by the Gitea webhook)
4. If it does not start in 30 seconds, click **Build Now** manually

### Step 4 — Follow the build

Click on the running build (#1) → **Console Output**

Read through the log as it runs. Notice:
- The Python version printed in the Checkout stage
- The list of installed packages
- Individual test names and their pass/fail status
- The coverage report showing which lines are NOT covered

### Step 5 — Explore the build results

After the build succeeds:

- **Stage View** (on the job page): see timing for each stage
- **Test Results** link: see all 30+ tests with their status
- **Build Artifacts**: download the `bandit-report.txt`
- **Console Output**: the complete log with timestamps

### Step 6 — Deliberately break the pipeline

Learning happens when things fail. Try each of these and observe what happens:

**Break lint:**
```python
# In app/api.py, add a line that is too long or has a style error
import os,sys  # flake8: E401 (multiple imports on one line)
```

**Break formatting:**
```python
# In app/api.py, add poorly formatted code
x=1  # black would format this as `x = 1`
```

**Break a test:**
```python
# In tests/test_api.py, change a 200 assertion to 201
def test_returns_200(self, client):
    response = client.get("/health")
    assert response.status_code == 201  # Wrong — will fail
```

Push each broken change and watch the pipeline fail at the right stage. This is more valuable than reading about it.

### Step 7 — Verify the Docker image (main branch)

After a successful build on `main`:

```bash
# List images in your local registry
curl -s http://localhost:5000/v2/flask-todo-api/tags/list | python3 -m json.tool

# Pull and run the image
docker pull localhost:5000/flask-todo-api:latest
docker run -p 5000:5000 localhost:5000/flask-todo-api:latest

# In another terminal, test the running app
curl http://localhost:5000/health
curl http://localhost:5000/todos
curl -X POST http://localhost:5000/todos \
     -H "Content-Type: application/json" \
     -d '{"title": "My first CI/CD todo", "description": "Built by Jenkins"}'
```

You just ran a Docker image that was built by a Jenkins pipeline, stored in a registry, and deployed to your laptop — all for free.

---

## Running Tests Locally

Before pushing, always run the pipeline steps locally. This saves time compared to pushing and waiting for Jenkins.

```bash
# Set up a virtual environment
python -m venv .venv
source .venv/bin/activate         # Linux/Mac
# .venv\Scripts\activate          # Windows

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Lint
flake8 app/ tests/

# Format check (reports only)
black --check app/ tests/

# Security scan
bandit -r app/ --severity-level medium

# Tests with coverage
pytest tests/ --cov=app --cov-report=term-missing --cov-fail-under=80 -v

# Fix formatting (modifies files)
black app/ tests/
```

---

## Troubleshooting

### Build not triggering on push

1. Check the Gitea webhook: Repository → Settings → Webhooks → look for green or red delivery icons
2. Check that Jenkins is running: `docker compose ps`
3. In Jenkins, check the job configuration: is the Gitea webhook enabled?
4. Manually trigger: click **Build Now** to confirm the Jenkinsfile itself is valid

### `flake8: command not found`

The pipeline runs inside a Docker container. flake8 is installed as part of the pipeline in the Install Dependencies stage. If you see this error, the install stage probably failed — scroll up in the console output.

### `black --check` reports differences

```bash
# See exactly what black would change
black --check --diff app/ tests/

# Let black fix it
black app/ tests/
git diff  # review changes
git add -p && git commit -m "style: apply black formatting"
```

### Docker build fails: `Cannot connect to the Docker daemon`

The Docker CLI container needs the Docker socket mounted. Check the Jenkinsfile:
```groovy
args '-v /var/run/docker.sock:/var/run/docker.sock'
```
Also verify the Jenkins Docker agent can access the socket:
```bash
docker exec jenkins docker info 2>&1 | head -5
```

### Push fails: `http: server gave HTTP response to HTTPS client`

The local registry is not TLS-secured. Docker needs it in the insecure-registries list. See [Step 2 of the lab setup](../../00-local-lab-setup/README.md#step-2--configure-docker-to-trust-the-local-registry).

### Coverage below 80%

```bash
# See which lines are not covered
pytest tests/ --cov=app --cov-report=term-missing

# Lines shown as "Missing" in the report are not executed by any test.
# Write tests that exercise those code paths.
```

---

## Extending the Pipeline

Once the basic pipeline is working, try these progressions:

### Extension 1: Make the security scan fail on HIGH severity

Change `|| true` to enforce the scan:
```groovy
sh '''
    bandit -r app/ \
        --severity-level high \
        -f txt \
        -o bandit-report.txt
    cat bandit-report.txt
'''
```

Now add a deliberate vulnerability and watch the pipeline stop:
```python
# app/api.py — add a hardcoded secret (HIGH severity in bandit)
SECRET_KEY = "hardcoded-secret-abc123"  # bandit: B105
```

### Extension 2: Run lint and format in parallel

Independent stages can run simultaneously, reducing total pipeline time:

```groovy
stage('Code Quality') {
    parallel {
        stage('Lint') {
            steps { sh 'flake8 app/ tests/' }
        }
        stage('Format Check') {
            steps { sh 'black --check app/ tests/' }
        }
    }
}
```

### Extension 3: Add a smoke test after Docker build

After building and pushing the image, run it and verify it responds:

```groovy
stage('Smoke Test') {
    steps {
        sh '''
            # Start the container in the background
            docker run -d --name smoke-test -p 5001:5000 ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}

            # Wait for it to be ready
            sleep 5

            # Hit the health endpoint
            curl --retry 5 --retry-delay 2 --retry-connrefused \
                 http://localhost:5001/health

            # Clean up
            docker stop smoke-test && docker rm smoke-test
        '''
    }
}
```

### Extension 4: Use a multi-branch pipeline

Instead of a single pipeline job, create a **Multibranch Pipeline** in Jenkins. It automatically discovers all branches in your Gitea repository and creates a separate pipeline for each. You get:
- Instant feedback per feature branch
- Branch-specific behavior via `when { branch 'main' }` conditions
- Automatic cleanup when branches are deleted

---

## Key Takeaways

1. **CI/CD is automation of quality gates** — the same checks a careful human would do, automated and enforced on every push.

2. **Each stage has a cost and a benefit** — lint catches style issues cheaply; tests catch logic bugs; security scans catch vulnerabilities. The cost of running them is minutes; the cost of skipping them is bugs in production.

3. **Docker agents make build environments reproducible** — no Python installed on the Jenkins host, no "it works on my machine" problems. The pipeline defines its own environment.

4. **`stash` / `unstash` is Jenkins's file transfer mechanism** — when different stages use different agents (containers), files must be explicitly passed between them. Understanding this unlocks complex multi-stage pipelines.

5. **The `when { beforeAgent true }` pattern is important** — always evaluate branch conditions before allocating a build agent. This prevents unnecessary resource usage for skipped stages.

6. **Tests are the quality gate** — `--cov-fail-under=80` enforces that new code has tests. Without enforcement, coverage erodes over time. With enforcement, every developer knows what is expected.

---

## Security Considerations

1. **Credentials are never in the Jenkinsfile** — they come from the Jenkins credentials store (configured via JCasC in the lab setup).
2. **The production Docker image runs as a non-root user** — see the `Dockerfile` `useradd` step.
3. **Dev dependencies are not in the production image** — `requirements-dev.txt` is only used in the pipeline.
4. **Security scanning is part of the pipeline** — not an afterthought.

---

## References

- [Flask Documentation](https://flask.palletsprojects.com/)
- [pytest Documentation](https://docs.pytest.org/)
- [flake8 Documentation](https://flake8.pycqa.org/)
- [black Documentation](https://black.readthedocs.io/)
- [Bandit Documentation](https://bandit.readthedocs.io/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Jenkins Docker Pipeline Plugin](https://plugins.jenkins.io/docker-workflow/)

---

## Next Project

Ready for more? Try adding a real database (PostgreSQL) to the app and updating the pipeline to run integration tests against it.

Or jump to the advanced section:

[12 — Security](../../12-security/README.md) · [13 — Monitoring](../../13-monitoring/README.md)
