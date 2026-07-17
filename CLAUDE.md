# CLAUDE.md

Repository guidance for future AI-assisted contributions.

## Repository Purpose

`ultimate-jenkins-devops` is a learner-first Jenkins training repository. It should stay practical, honest about implementation status, secure by default, and easy to extend.

## Current Rules

- Preserve useful existing content when improving modules.
- Do not claim a module is fully implemented unless it has runnable assets and validation.
- Prefer repeatable labs over long prose when adding new material.
- Keep real-world projects numbered only when real implementation exists.
- Store Mermaid source files with the module that owns the diagram.

## Content Standards

Every major lab or project should include:

- prerequisites
- estimated duration
- environment and cost notes
- expected output
- validation commands or a validation script
- troubleshooting notes
- cleanup steps

## Jenkins Standards

- avoid builds on the controller
- use explicit agent labels
- use timeouts and build retention
- use credential IDs instead of hardcoded secrets
- explain local-lab shortcuts such as Docker socket mounting

## Versioning and Validation

- update [COMPATIBILITY.md](./COMPATIBILITY.md) when changing version assumptions
- update [CHANGELOG.md](./CHANGELOG.md) for visible repository changes
- record gaps or unverified items in [REPOSITORY-IMPROVEMENT-REPORT.md](./REPOSITORY-IMPROVEMENT-REPORT.md)
