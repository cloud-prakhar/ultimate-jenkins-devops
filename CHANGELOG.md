# Changelog

## Unreleased

### Added

- `examples/` — 15 runnable demonstration pipelines with per-example Jenkins UI
  walkthroughs. `examples/pipeline-scripts/` covers declarative syntax
  (multi-stage, parameters, parallel, conditionals, artifacts and test reports,
  post conditions, Docker agents, credentials, error handling) plus one scripted
  pipeline; `examples/github-integration/` covers SCM checkout, multibranch and
  pull requests, webhooks and triggers, tag-based releases, and commit status
  reporting. Every example targets the `00-local-lab-setup` lab and uses only
  preinstalled plugins
- `examples/validate-examples.sh`, which lints each example against a running
  Jenkins via the declarative linter endpoint
- `_typos.toml` allowing the `crate-ci/typos` spell-check job's only false
  positives (`Hashi` from HashiCorp/HashiConf, `RTO` = Recovery Time Objective)
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

- Silenced hadolint `DL3008` (unpinned apt versions) on the two local-lab
  Dockerfiles (Jenkins controller and agent) with a documented inline
  `# hadolint ignore`, so `code-validation` lint passes; the Flask production
  image stays strict
- Split `code-validation` into per-concern jobs and set the `GITHUB_TOKEN`
  that `gitleaks-action@v2` requires (the secret scan previously failed)
- Rebuilt `docs-validation` so markdown lint, spell check, mermaid validation,
  and link checking each report independently; link check no longer hard-fails
  the pipeline on third-party outages
- Added least-privilege `permissions` and `concurrency` blocks to every
  workflow
- EC2 bootstrap scripts (`terraform/user-data.sh` and
  `cloud-init/install-jenkins.sh`) aborted on first boot when Ubuntu's
  `unattended-upgrades` timer held the dpkg lock, leaving instances with no
  `jenkins.service` at all. Both now wait for `cloud-init`, use
  `DPkg::Lock::Timeout`, retry transient failures, and log to
  `/var/log/jenkins-bootstrap.log`
- Set `user_data_replace_on_change = true` on the Jenkins instance, so editing
  the bootstrap script and re-applying actually re-runs it, and required
  IMDSv2 via `metadata_options`
- **Expired Jenkins signing key.** Every install path used
  `jenkins.io-2023.key`, which expired on 2026-03-26 — `apt-get update` failed
  with `NO_PUBKEY 7198F4B714ABFC68` and Jenkins could not be installed at all.
  `scripts/install-jenkins-ubuntu.sh`, `terraform/user-data.sh`,
  `cloud-init/install-jenkins.sh` and `02-installation/README.md` now use a
  key that is current, and the scripts auto-detect the year's key and reject
  expired ones so the next rotation does not break them. Verified on EC2.
- **Boot deadlock in the EC2 bootstrap.** The dpkg-lock fix used
  `cloud-init status --wait`, but as user data the script is a *child* of
  cloud-init — so it waited on a process waiting on itself and hung the boot
  forever with nothing installed. Replaced with a bounded wait on the dpkg
  lock plus stopping the apt timers.
- **Bootstrap was not safely re-runnable.** A failed run left a broken
  `jenkins.list` behind, which then broke the *first* `apt-get update` of
  every later run — so retrying failed for a new and more confusing reason.
  All install scripts now clear the stale Jenkins repo and keyring first.
- Rewrote `04-installing-jenkins.md` from a 4-command stub into an end-to-end
  post-launch guide: SSM shell, bootstrap verification, a diagnosis table for
  `Unit jenkins.service could not be found`, manual recovery, port forwarding,
  and unlocking the wizard; `02`, `03`, and `11` now link into it

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
