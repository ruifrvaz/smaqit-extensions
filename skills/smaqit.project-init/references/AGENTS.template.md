# Scaffolding

This project uses **smaqit-extensions** scaffolding to support AI-assisted development workflows. The scaffolding files are **not part of this project's business domain**.

Execute skills verbatim. When a skill specifies a sequence of scripts or tool invocations, execute every step in the documented order without skipping, merging, or streamlining. Skill scripts encapsulate non-obvious side effects such as sparse checkout, cleanup, and validation. Never substitute manual commands merely because they appear equivalent.

When reasoning about business context, architecture, domain logic, or project conventions, **ignore the following smaqit scaffolding paths entirely**:

- `.smaqit/` — smaqit state directory (task planning, session history, templates, user-testing artefacts)
- `.github/workflows/` — smaqit CI workflows (e.g., release automation)

A project that explicitly used `smaqit-extensions install --scope project` additionally carries installed agent/skill mirror directories (`.github/agents/`, `.github/skills/`, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.codex/agents/`, `.agents/skills/`) — ignore those the same way if present. Under the default global install this project has none of them.

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
