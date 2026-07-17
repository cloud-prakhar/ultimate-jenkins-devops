# CODEX.md

Repository support notes for future AI-assisted maintenance.

## Purpose

`ultimate-jenkins-devops` is a practical Jenkins learning platform. Changes should improve learner outcomes, honesty of repository status, repeatability of labs, and security defaults.

## Architecture Decisions

- Keep the controller separate from build execution wherever possible.
- Use a dedicated local `linux` agent for the Docker lab.
- Keep examples approachable; avoid fake enterprise complexity.
- Prefer local-first labs before cloud labs.
- Use Mermaid source files retained in the repository.

## Naming and Content Rules

- Numbered modules use `NN-topic-name/`
- Implemented real-world projects start at `01-...`
- Planned projects belong in roadmap tables until real assets exist
- Labs need validation and cleanup instructions

## Validation Expectations

- Document what was tested
- Mark unverified items explicitly
- Prefer pinned versions for core components
- Update [COMPATIBILITY.md](./COMPATIBILITY.md) when changing environment assumptions

## Known Issues and Roadmap

- Several older modules still contain ASCII diagrams
- Advanced modules remain more conceptual than hands-on
- Jenkins plugin version drift should be watched closely when refreshing the local lab image
