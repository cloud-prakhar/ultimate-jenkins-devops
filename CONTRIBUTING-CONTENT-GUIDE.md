# Contributing Content Guide

Use this guide when adding or refactoring repository learning content.

## Module Standard

Every major module should contain or clearly reference:

1. Overview
2. Learning objectives
3. Prerequisites
4. Estimated duration
5. Difficulty level
6. Required environment
7. Cost information
8. Theory
9. Architecture
10. Hands-on lab
11. Expected output
12. Validation commands
13. Break-it exercise
14. Troubleshooting
15. Cleanup
16. Quiz
17. Independent challenge
18. Solution
19. Additional reading
20. Official documentation references

## Directory Template

Start from [templates/module-template](./templates/module-template/README.md).

Do not create placeholder files unless they contain concrete guidance, a roadmap table, or reusable scaffolding.

## Writing Style

For important concepts:

1. Explain it technically.
2. Explain it in simple language.
3. Give a real-world example.
4. Explain why it matters.
5. Mention common mistakes.
6. Provide a validation command or observable result.

## Lab Standard

Every repeatable lab should include:

- `README.md`
- `starter/` and `solution/` only when there is real learner value
- a validation script or explicit validation commands
- cleanup steps
- a troubleshooting section
- a security note if the lab uses a shortcut such as Docker socket mounting

## Diagram Standard

- Use Mermaid `.mmd` source files for GitHub-rendered diagrams.
- Use `flowchart TD` for architecture and `flowchart LR` for flows unless a different layout is clearer.
- Keep node labels readable and expand acronyms on first mention nearby.
- Add a short text explanation below each diagram in the owning markdown file.

## Review Checklist

- Is the module honest about its status?
- Can a beginner follow it without making hidden assumptions?
- Are version assumptions explicit?
- Are cleanup steps safe and understandable?
- Are secrets, ports, labels, and credential IDs clearly documented?
