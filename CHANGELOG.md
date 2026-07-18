# Changelog

## Unreleased

### Added

- `.markdownlint-cli2.jsonc` config so `markdownlint` runs with intentional,
  prose-friendly rules instead of failing on ~800 default-rule violations
- `.lycheeignore` to exclude lab-local and placeholder hosts from link checks
- `scripts/validate-mermaid.sh`, which validates both `.mmd` files and
  ` ```mermaid ` fenced blocks (the old CI step checked neither correctly)

### Changed

- Converted all ASCII/box-drawing architecture and flow diagrams across the
  learning modules to `mermaid` diagrams; tagged remaining mockups and
  directory trees as `text` fenced blocks
- Rewrote the manual EC2 console deployment guide with plain-language
  explanations, analogies, real-world use cases, and end-to-end
  `localhost:8080` access via Systems Manager port forwarding
- Expanded `01-fundamentals` with an everyday-analogy terminology table and a
  real-world CI/CD scenario
- Added a beginner "Introduction to CI/CD" on-ramp to `01-fundamentals` with
  plain-language analogies, a conveyor-belt pipeline diagram, and real-world
  examples (Amazon, Netflix, startup, banking)

### Fixed

- Split `code-validation` into per-concern jobs and set the `GITHUB_TOKEN`
  that `gitleaks-action@v2` requires (the secret scan previously failed)
- Rebuilt `docs-validation` so markdown lint, spell check, mermaid validation,
  and link checking each report independently; link check no longer hard-fails
  the pipeline on third-party outages
- Added least-privilege `permissions` and `concurrency` blocks to every
  workflow

## 0.2.0 - 2026-07-17

### Added

- Local Docker lab restructure with controller and dedicated `linux` agent
- AWS EC2 single-instance Jenkins lab with manual and Terraform deployment tracks
- Learner and instructor resource packs
- Module template and content contribution guide
- Validation workflows for docs, code, Terraform, and repository smoke tests
- Troubleshooting debugging lab scenarios

### Changed

- Corrected root README repository status claims
- Renumbered the Flask real-world project from Project 11 to Project 01
- Added compatibility, security, contributing, and improvement report documents
- Added repository-wide diagram standards and catalog

### Fixed

- Local Jenkins architecture mismatch between `numExecutors: 0` and pipeline label usage
- Project numbering and internal links for the implemented Flask project
