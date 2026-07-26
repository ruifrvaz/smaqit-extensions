# Scaffolding

This project uses **smaqit-extensions** scaffolding to support AI-assisted development workflows. The scaffolding files are **not part of this project's business domain**.

Execute skills verbatim. When a skill specifies a sequence of scripts or tool invocations, execute every step in the documented order without skipping, merging, or streamlining. Skill scripts encapsulate non-obvious side effects such as sparse checkout, cleanup, and validation. Never substitute manual commands merely because they appear equivalent.

When reasoning about business context, architecture, domain logic, or project conventions, **ignore the following smaqit scaffolding paths entirely**:

- `.smaqit/` — smaqit state directory (task planning, session history, templates, user-testing artefacts)
- `.github/agents/` — smaqit utility agents (release, user-testing), for GitHub Copilot
- `.github/skills/` — smaqit workflow skills (session, task, release, test), for GitHub Copilot
- `.github/workflows/` — smaqit CI workflows (e.g., `test-sync.yml`)
- `.claude/agents/` — smaqit utility agents, for Claude Code
- `.claude/skills/` — smaqit workflow skills, for Claude Code
- `.claude/commands/` — smaqit slash commands, for Claude Code
- `.codex/agents/` — smaqit utility agents, for Codex
- `.agents/skills/` — smaqit workflow skills, for Codex
- `installer/` — smaqit installer source code
- `agents/` — smaqit agent source files (if present at repo root)
- `skills/` — smaqit skill source files (if present at repo root)
- `commands/` — smaqit Claude Code command source files (if present at repo root)
- `scripts/` — smaqit build/generator scripts (if present at repo root)

These files exist to support developer workflow automation and are maintained separately from the project's own code. They do not represent business requirements, domain models, or architectural decisions for this project.

## Desktop Linux SSH Agent Recovery

When an explicitly authorized Git SSH operation fails with `Permission denied (publickey)`, `sign_and_send_pubkey`, or a missing `ssh-askpass`, an interactive WSL2/WSLg, Ubuntu/GNOME, or XFCE session may have a usable agent socket that the current process did not inherit.

Inspect already-running agents in this order: `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gcr/ssh`, `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring/ssh`, the socket reported by `gpgconf --list-dirs agent-ssh-socket`, the current `SSH_AUTH_SOCK`, and the `SSH_AUTH_SOCK` value from `systemctl --user show-environment`. Select the first existing socket for which command-scoped `ssh-add -l` lists identities, then retry only the exact failed Git command once:

```bash
SSH_AUTH_SOCK="$agent_socket" git push origin main
```

GCR or GNOME Keyring may display a WSLg/GNOME unlock dialog; GnuPG or a confirmation-constrained OpenSSH agent may display its configured pinentry or askpass prompt. If no usable socket is found, signing still fails, the command times out, or the prompt was closed, stop and ask the user to reopen/unlock their desktop key store or SSH agent before retrying.

Never use this recovery in CI or another headless environment. Do not start or replace agents, persist `SSH_AUTH_SOCK`, edit shell startup files, load or remove identities, change remote transport, or use the unlocked agent for any operation beyond the one the user already authorized.

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
