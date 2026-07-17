# AWS EC2 Single-Instance Jenkins Lab

This module teaches how to launch Jenkins on one Ubuntu 24.04 LTS EC2 instance for demos, workshops, and self-paced learning. It is intentionally simple and uses AWS Systems Manager Session Manager instead of public SSH by default.

## Module Summary

| Field | Value |
| --- | --- |
| Level | Beginner-Intermediate |
| Estimated duration | 90-120 minutes |
| Environment | AWS account, AWS CLI v2, Session Manager plugin, Terraform optional |
| Cost | Pay for EC2, EBS, and any optional CloudWatch usage |
| Default access model | Session Manager shell and port forwarding |
| Validation | `./scripts/preflight.sh`, `./scripts/verify-instance.sh`, `./scripts/verify-jenkins.sh` |

## Why This Lab Exists

Technical explanation:

- many teams still run Jenkins on a single virtual machine for learning, PoCs, or small internal environments
- EC2 is a common place to demonstrate Jenkins installation, backup, service management, and cloud security basics

Simple explanation:

- this lab shows how to run Jenkins on one cloud server without opening risky ports to the whole internet

## Security Defaults

- no inbound SSH from `0.0.0.0/0`
- no inbound Jenkins `8080` from `0.0.0.0/0`
- Session Manager is the default shell and tunnel path
- IAM role is used for instance access instead of stored AWS keys

Optional fallback:

- you may temporarily allow `8080` from `YOUR_PUBLIC_IP/32` for a live demo
- label that choice as less secure and remove it during cleanup

## Suggested Learning Order

1. [01-architecture-and-prerequisites.md](./01-architecture-and-prerequisites.md)
2. [02-manual-console-deployment.md](./02-manual-console-deployment.md)
3. [03-terraform-deployment.md](./03-terraform-deployment.md)
4. [04-installing-jenkins.md](./04-installing-jenkins.md)
5. [05-initial-jenkins-configuration.md](./05-initial-jenkins-configuration.md)
6. [06-first-freestyle-job.md](./06-first-freestyle-job.md)
7. [07-first-pipeline.md](./07-first-pipeline.md)
8. [08-configuring-docker-agent.md](./08-configuring-docker-agent.md)
9. [09-backup-and-restore.md](./09-backup-and-restore.md)
10. [10-monitoring-and-logs.md](./10-monitoring-and-logs.md)
11. [11-troubleshooting.md](./11-troubleshooting.md)
12. [12-cleanup.md](./12-cleanup.md)

## Quick Start

```bash
cd 02-installation/aws-ec2-single-instance
./scripts/preflight.sh
terraform -chdir=terraform init
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform apply
```

Then use the output Session Manager command to open a shell or port forward:

```bash
aws ssm start-session \
  --target <INSTANCE_ID> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
```

## Diagrams

- [diagrams/ec2-single-instance.mmd](./diagrams/ec2-single-instance.mmd)
- [diagrams/ec2-controller-agent.mmd](./diagrams/ec2-controller-agent.mmd)
- [diagrams/ssm-access-flow.mmd](./diagrams/ssm-access-flow.mmd)

## Instructor and Learner Aids

- [instructor-guide.md](./instructor-guide.md)
- [learner-workbook.md](./learner-workbook.md)
