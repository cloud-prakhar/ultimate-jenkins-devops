# Security Policy

This repository is for learning Jenkins safely. Some labs intentionally simplify setup for local practice, but those shortcuts are always called out with safer production alternatives.

## Reporting

Do not open a public issue for a suspected security vulnerability that could affect real deployments. Report it privately to the repository maintainer with:

- affected file or module
- impact summary
- reproduction steps
- recommended mitigation if known

## Security Defaults in This Repository

- No committed secrets, tokens, or private keys
- Use `.env.example` rather than `.env`
- Use Jenkins credential IDs instead of inline secrets
- Prefer IAM roles over stored AWS keys
- Do not expose Jenkins or SSH publicly by default in cloud labs
- Do not run builds on the Jenkins controller
- Explain Docker socket risks where used
- Include secret scanning in repository automation

## Learner Security Checklist

- Replace default passwords in `.env` before sharing your screen or screenshots
- Keep lab systems local or protected; do not reuse example passwords outside a lab
- Verify Jenkins controller executors remain `0`
- Use credential IDs such as `gitea-credentials` and `registry-credentials`
- Remove or destroy cloud resources after the lab

## Instructor Security Checklist

- Pre-create demo accounts with non-sensitive credentials
- Use a dedicated AWS account or sandbox subscription for live sessions
- Avoid showing real tokens in terminal history or browser forms
- Prefer Session Manager over opening SSH to the internet
- Reset or destroy demo environments after training

## Known Lab Tradeoffs

The local Docker lab mounts `/var/run/docker.sock` into Jenkins and the agent. This is acceptable for a local learning environment because it keeps the setup short and reproducible. It is not safe for a shared or production environment because a container with Docker socket access can often control the host Docker daemon.

Safer production patterns:

- dedicated remote Linux agents
- Kubernetes ephemeral agents
- Kaniko
- BuildKit
- rootless builders
- isolated build nodes
