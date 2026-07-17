# Compatibility

This file documents the versions targeted by the repository as of July 17, 2026. Update this file when changing pinned images, scripts, Terraform constraints, or lab expectations.

## Tested and Targeted Versions

| Component | Version Strategy | Notes |
| --- | --- | --- |
| Jenkins | `jenkins/jenkins:2.516.3-lts-jdk21` | Pinned in the local lab |
| Jenkins inbound agent | `jenkins/inbound-agent:latest-jdk21` | Used for the local agent image build base |
| Java | 21 | Standard runtime for Jenkins and agent labs |
| Docker Engine | 26.x or newer | Required for local lab and Docker examples |
| Docker Compose | v2.24+ | `docker compose` plugin syntax expected |
| Python | 3.12 | Flask project and CI examples |
| Terraform | 1.9.x or newer | AWS EC2 module expects modern validation and provider syntax |
| AWS CLI | v2 | Required for Session Manager and lab scripts |
| Session Manager plugin | Latest AWS-supported v1.2+ | Required for `aws ssm start-session` port forwarding |
| Ubuntu | 24.04 LTS | AWS EC2 lab and Linux install examples |
| Kubernetes | 1.30+ | Advanced roadmap content target |
| Helm | 3.15+ | Advanced roadmap content target |

## Update Process

1. Update the pinned version in code or docs.
2. Re-run the relevant validation:
   - Docker Compose config
   - Python tests and image build
   - Terraform `fmt` and `validate`
   - Local lab smoke test
3. Update this file and [CHANGELOG.md](./CHANGELOG.md).
4. Note any unverified combinations in [REPOSITORY-IMPROVEMENT-REPORT.md](./REPOSITORY-IMPROVEMENT-REPORT.md).

## Notes

- Avoid `latest` tags for core images where reproducibility matters.
- Plugin versions are managed through `plugins.txt`; compatibility should be rechecked when updating the Jenkins base image.
- AWS AMIs must not be hardcoded. The EC2 module resolves Ubuntu 24.04 LTS via AWS-owned public parameters.
