# Diagram Standards

## File Naming

- use lowercase kebab-case names
- keep Mermaid source in `.mmd` files
- place module diagrams under the owning module where possible

## Direction

- use `flowchart TD` for architecture by default
- use `flowchart LR` for linear request or pipeline flows
- use `sequenceDiagram` for interaction flows

## Complexity

- prefer fewer than 12 nodes in a beginner diagram
- split large diagrams instead of creating unreadable all-in-one views

## Labels

- expand acronyms nearby on first mention
- keep node text short enough to render well on GitHub

## Accessibility

- add a short explanation below diagrams in markdown files
- do not rely on color alone to explain meaning

## Source Retention

- commit Mermaid source, not just screenshots
- use SVG only when cloud icons or print-friendly layouts are necessary

## Update Process

1. edit the `.mmd` source
2. validate Mermaid syntax locally or in CI
3. update the related markdown explanation if the design changed
