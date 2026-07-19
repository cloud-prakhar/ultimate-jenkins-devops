# Ultimate Jenkins DevOps

Practical Jenkins training for DevOps, cloud, SRE, and platform engineering learners. This repository mixes theory, repeatable labs, example applications, instructor material, and validation workflows so you can learn Jenkins by running it, not just reading about it.

## Who This Is For

- Beginners learning Jenkins, CI/CD, and build automation for the first time
- Instructors running live demos, workshops, and internal enablement sessions
- Self-paced learners who want guided labs with validation and cleanup
- Platform and DevOps engineers who need a growable Jenkins reference repo

## Start Here

```bash
git clone https://github.com/cloud-prakhar/ultimate-jenkins-devops.git
cd ultimate-jenkins-devops/00-local-lab-setup
cp .env.example .env
./scripts/start-lab.sh
```

## Current Repository Status

Status legend: `✅ Available` `🚧 In Progress` `📌 Planned` `🧪 Experimental` `🛠 Needs Validation`

| Module or Project | Level | Status | Environment | Approximate Duration |
| --- | --- | --- | --- | --- |
| [00-local-lab-setup](./00-local-lab-setup/README.md) | Beginner | ✅ Available | Docker Desktop or Docker Engine | 30-45 minutes |
| [01-fundamentals](./01-fundamentals/README.md) | Beginner | ✅ Available | Documentation | 45-60 minutes |
| [02-installation](./02-installation/README.md) | Beginner | 🚧 In Progress | Local Linux, Docker, AWS | 60-120 minutes |
| [02-installation/aws-ec2-single-instance](./02-installation/aws-ec2-single-instance/README.md) | Beginner-Intermediate | ✅ Available | AWS account, Terraform optional | 90-120 minutes |
| [03-jenkins-ui](./03-jenkins-ui/README.md) | Beginner | ✅ Available | Jenkins UI | 45-60 minutes |
| [04-freestyle-jobs](./04-freestyle-jobs/README.md) | Beginner | ✅ Available | Jenkins UI | 45-60 minutes |
| [05-pipelines](./05-pipelines/README.md) | Beginner-Intermediate | 🚧 In Progress | Local lab | 60-90 minutes |
| [06-declarative-pipelines](./06-declarative-pipelines/README.md) | Intermediate | ✅ Available | Jenkins UI and git repo | 60-90 minutes |
| [07-scripted-pipelines](./07-scripted-pipelines/README.md) | Intermediate | ✅ Available | Jenkins UI and git repo | 60-90 minutes |
| [08-shared-libraries](./08-shared-libraries/README.md) | Intermediate | 📌 Planned | Jenkins + SCM | 90 minutes |
| [09-docker-integration](./09-docker-integration/README.md) | Intermediate | 🚧 In Progress | Local lab | 60-90 minutes |
| [10-kubernetes-integration](./10-kubernetes-integration/README.md) | Advanced | 📌 Planned | Kubernetes cluster | 2-4 hours |
| [11-production-grade-jenkins](./11-production-grade-jenkins/README.md) | Advanced | 🚧 In Progress | Kubernetes or cloud VM | 2-4 hours |
| [12-security](./12-security/README.md) | Intermediate-Advanced | 🚧 In Progress | Local lab and AWS | 60-90 minutes |
| [13-monitoring](./13-monitoring/README.md) | Advanced | 📌 Planned | Jenkins + monitoring stack | 90-120 minutes |
| [14-troubleshooting](./14-troubleshooting/README.md) | All levels | 🚧 In Progress | Local lab | 60-120 minutes |
| [15-real-world-projects/01-python-flask-todo-api](./15-real-world-projects/01-python-flask-todo-api/README.md) | Beginner-Intermediate | ✅ Available | Local lab | 60-90 minutes |
| [15-real-world-projects](./15-real-world-projects/README.md) | Mixed | 🚧 In Progress | Mixed | Mixed |
| [examples](./examples/README.md) | Beginner-Intermediate | 🛠 Needs Validation | Local lab | 15 examples, 1-10 minutes each |
| [instructor-resources](./instructor-resources/README.md) | Instructor | ✅ Available | Documentation | 20-30 minutes |
| [learner-resources](./learner-resources/README.md) | All levels | ✅ Available | Documentation | Self-paced |
| [templates/module-template](./templates/module-template/README.md) | Contributor | ✅ Available | Documentation | 20 minutes |

## What Is Actually Implemented Today

- A local Jenkins learning lab with Jenkins controller, a functional `linux` agent, Gitea, and a local Docker registry
- A practical Flask Todo API project with beginner and intermediate Jenkinsfiles
- An AWS EC2 single-instance Jenkins live-demo lab with manual and Terraform paths
- Fifteen runnable [example pipelines](./examples/README.md) with step-by-step Jenkins UI walkthroughs, covering declarative and scripted syntax plus SCM, multibranch, webhook, and release integration
- Learner, instructor, troubleshooting, and contribution resources
- GitHub Actions validation workflows for docs, code, Terraform, and repository smoke tests

## What Is Still Growing

- Several numbered learning modules are still documentation-heavy rather than lab-heavy
- Kubernetes, monitoring, shared library, and production governance content remain partially implemented or roadmap content
- Some older module diagrams still need conversion from ASCII to Mermaid
- Full end-to-end Jenkins job execution is documented, but may require local Docker availability to verify on every contributor machine

## Learning Tracks

### Beginner Track

1. [00-local-lab-setup](./00-local-lab-setup/README.md)
2. [01-fundamentals](./01-fundamentals/README.md)
3. [02-installation](./02-installation/README.md)
4. [03-jenkins-ui](./03-jenkins-ui/README.md)
5. [04-freestyle-jobs](./04-freestyle-jobs/README.md)
6. [05-pipelines](./05-pipelines/README.md)
7. [15-real-world-projects/01-python-flask-todo-api](./15-real-world-projects/01-python-flask-todo-api/README.md)

Typical duration: 6-10 hours. Cloud cost: none if you stay on the local lab.

### Intermediate Track

1. [06-declarative-pipelines](./06-declarative-pipelines/README.md)
2. [07-scripted-pipelines](./07-scripted-pipelines/README.md)
3. [09-docker-integration](./09-docker-integration/README.md)
4. [12-security](./12-security/README.md)
5. [14-troubleshooting](./14-troubleshooting/README.md)
6. [02-installation/aws-ec2-single-instance](./02-installation/aws-ec2-single-instance/README.md)

Typical duration: 8-12 hours. Cloud cost: small EC2 and EBS cost if you run the AWS lab.

### Advanced Track

1. [08-shared-libraries](./08-shared-libraries/README.md)
2. [10-kubernetes-integration](./10-kubernetes-integration/README.md)
3. [11-production-grade-jenkins](./11-production-grade-jenkins/README.md)
4. [13-monitoring](./13-monitoring/README.md)

Typical duration: 10+ hours. Cloud or Kubernetes cost may apply.

### Instructor Track

- [instructor-resources/90-minute-session-plan.md](./instructor-resources/90-minute-session-plan.md)
- [instructor-resources/2-hour-session-plan.md](./instructor-resources/2-hour-session-plan.md)
- [instructor-resources/one-day-workshop-plan.md](./instructor-resources/one-day-workshop-plan.md)
- [instructor-resources/live-demo-checklist.md](./instructor-resources/live-demo-checklist.md)
- [instructor-resources/demo-recovery-plan.md](./instructor-resources/demo-recovery-plan.md)
- [02-installation/aws-ec2-single-instance/instructor-guide.md](./02-installation/aws-ec2-single-instance/instructor-guide.md)

## Repository Layout

```text
00-local-lab-setup/              Local Docker lab
01-14/                           Learning modules by topic
15-real-world-projects/          End-to-end projects and roadmap
examples/                        15 runnable demo pipelines with UI walkthroughs
instructor-resources/            Session plans and recovery checklists
learner-resources/               Prerequisites, glossary, interview prep
templates/module-template/       Standard content template for new modules
diagrams/                        Repository-wide diagram standards and catalog
.github/workflows/               Validation workflows
```

## Environments and Cost

| Environment | Used For | Cost |
| --- | --- | --- |
| Local Docker lab | Beginner practice, pipelines, Flask project | Free |
| Local Linux host | Manual Jenkins installation exercises | Free |
| AWS EC2 single instance | Live demo, cloud installation, backup and restore | Pay only while resources exist |
| Kubernetes cluster | Advanced and roadmap content | Usually paid unless local cluster |

Review [COMPATIBILITY.md](./COMPATIBILITY.md) before pinning your own versions.

## Security Defaults

- Local lab does not expose Jenkins or SSH beyond localhost
- AWS EC2 lab uses AWS Systems Manager Session Manager instead of public SSH by default
- Jenkins controller is configured with `numExecutors: 0` and a separate build agent
- Examples use credential IDs, placeholders, or IAM roles instead of committed secrets
- The Docker socket pattern is documented as a local-lab-only shortcut with explicit production alternatives

Read [SECURITY.md](./SECURITY.md) before reusing any example in a non-lab environment.

## How to Contribute

- Read [CONTRIBUTING.md](./CONTRIBUTING.md)
- Follow [CONTRIBUTING-CONTENT-GUIDE.md](./CONTRIBUTING-CONTENT-GUIDE.md)
- Use [templates/module-template](./templates/module-template/README.md) for new labs
- Review [diagrams/standards.md](./diagrams/standards.md) before adding or updating diagrams

## Support and Reporting

- Bugs, broken links, and missing validation steps: open a GitHub issue
- Security concerns: follow the reporting guidance in [SECURITY.md](./SECURITY.md)
- Content gaps or roadmap ideas: use discussions or issues with a module reference

## Additional Reference Files

- [REPOSITORY-IMPROVEMENT-REPORT.md](./REPOSITORY-IMPROVEMENT-REPORT.md)
- [COMPATIBILITY.md](./COMPATIBILITY.md)
- [CHANGELOG.md](./CHANGELOG.md)
- [15-real-world-projects/README.md](./15-real-world-projects/README.md)
