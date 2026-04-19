# Scaffolding

This project uses **smaqit-extensions** scaffolding to support AI-assisted development workflows. The scaffolding files are **not part of this project's business domain**.

When reasoning about business context, architecture, domain logic, or project conventions, **ignore the following smaqit scaffolding paths entirely**:

- `.smaqit/` — smaqit state directory (task planning, session history, templates, user-testing artefacts)
- `.github/agents/` — smaqit utility agents (release, user-testing)
- `.github/skills/` — smaqit workflow skills (session, task, release, test)
- `.github/workflows/` — smaqit CI workflows (e.g., `test-sync.yml`)
- `installer/` — smaqit installer source code
- `agents/` — smaqit agent source files (if present at repo root)
- `skills/` — smaqit skill source files (if present at repo root)

These files exist to support developer workflow automation and are maintained separately from the project's own code. They do not represent business requirements, domain models, or architectural decisions for this project.

# Project

## Project Name

[TODO: add project name]

## Purpose / Goal

[TODO: describe the problem this project solves and its main objective]

## Tech Stack

[TODO: list primary languages, frameworks, libraries, and infrastructure — e.g., Go 1.22, PostgreSQL 16, React 18, deployed on AWS ECS]

## Key Conventions

[TODO: document coding style, branching strategy, naming rules, testing approach, and any other conventions the AI should follow — e.g., "use conventional commits", "all public functions must have doc comments", "tests live alongside source files"]

## Domain Context

[TODO: add any additional business domain knowledge, architectural constraints, or context the AI should be aware of]
