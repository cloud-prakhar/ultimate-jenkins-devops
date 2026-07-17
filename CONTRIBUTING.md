# Contributing

This repository is maintained as a learner-first Jenkins training platform. Contributions should improve practical learning value, technical accuracy, repeatability, and security.

## Before You Start

1. Read [CONTRIBUTING-CONTENT-GUIDE.md](./CONTRIBUTING-CONTENT-GUIDE.md).
2. Check [COMPATIBILITY.md](./COMPATIBILITY.md) for tested versions.
3. Use the module template in [templates/module-template](./templates/module-template/README.md) for new content.
4. Prefer extending an existing module over creating empty folders.

## Contribution Rules

- Preserve useful existing explanations when improving content.
- Mark module maturity honestly using the status legend in the root README.
- Every lab must include prerequisites, validation, troubleshooting, and cleanup.
- Use placeholders, example IDs, or `.env.example` files instead of real secrets.
- Prefer Mermaid source files stored with the module.
- Keep examples beginner-friendly unless the module is explicitly advanced.

## Validation Expectations

Run the checks relevant to your change:

```bash
markdownlint "**/*.md"
shellcheck scripts/*.sh
docker compose -f 00-local-lab-setup/docker-compose.yml config
pytest 15-real-world-projects/01-python-flask-todo-api/tests
terraform -chdir=02-installation/aws-ec2-single-instance/terraform fmt -check
terraform -chdir=02-installation/aws-ec2-single-instance/terraform validate
```

If you cannot run a check, document that clearly in your pull request or issue.

## Content Changes

- Add expected output for important learner steps.
- Add at least one failure scenario for significant labs.
- Link official documentation in each major module.
- Keep diagrams close to the module that owns them.

## Pull Request Guidance

- Use a clear title that names the module or lab changed.
- Summarize what was tested and what remains unverified.
- Note any environment assumptions such as Docker, AWS CLI, or Terraform versions.
