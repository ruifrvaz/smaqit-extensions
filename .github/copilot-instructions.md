# Copilot Instructions for smaqit-extensions

## Repository Structure

This repository is the canonical source for smaqit-extensions agents and skills.

**Source files:**
- `agents/` — Agent bodies (no frontmatter; platform metadata in `.smaqit/definitions/agents/`)
- `skills/` — Skill implementations (29 skills)
- `commands/` — Claude Code slash-command wrappers
- `scripts/generate-targets.py` — Compiles source into platform-specific installer embed trees

**No committed mirrors.** Agents and skills are installed globally via the binary (run `./installer/dist/smaqit-extensions --install-global` after building, or install the latest release via `curl .../install.sh | bash`). The repo no longer carries `.github/agents/`, `.github/skills/`, `.claude/`, `.codex/agents/`, or `.agents/skills/` committed mirrors.

## Critical Rule: Build and install after source changes

After modifying source files in `agents/` or `skills/`, the changed content is not visible to your editor until you rebuild and reinstall:

```bash
cd installer
make prepare    # regenerate staging trees from canonical source
make build      # rebuild the Go binary
./dist/smaqit-extensions --install-global  # install to global paths
```

`make sync` now only regenerates the gitignored `installer/` staging trees — there are no committed mirrors to update. If you skip the `--install-global` step after building, your Copilot/Claude/Codex session will see stale skill content from the last install.

## Version Management

**ALWAYS update version numbers when modifying agents or skills.**

All agents and skills include version metadata in their frontmatter:

```yaml
---
name: smaqit.example
description: Example description
metadata:
  version: "0.2.0"
---
```

**Versioning rules:**
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Increment PATCH (0.1.0 → 0.1.1) for bug fixes or minor text changes
- Increment MINOR (0.1.0 → 0.2.0) for new functionality or significant changes
- Increment MAJOR (0.1.0 → 1.0.0) for breaking changes

**When to update versions:**
- Any change to frontmatter (name, description, metadata)
- Any change to file content (implementation, documentation, examples)
- Renaming files or directories
- Updating references to other resources

## Workflow for File Changes

```bash
# 1. Edit source files
vim agents/smaqit.release.pr.agent.md

# 2. Update version in frontmatter metadata

# 3. Build and install globally
cd installer
make prepare && make build
./dist/smaqit-extensions --install-global

# 4. Commit canonical source
git add agents/smaqit.release.pr.agent.md
git commit -m "fix: update release PR agent"
```

## Other Commands

```bash
make clean  # Remove installer staging build artifacts (installer/skills*, installer/agents-*, installer/dist/, etc.)
make sync   # Regenerate installer staging trees from canonical source (does not touch any committed path)
```

## Why This Structure?

- **Dogfooding**: Repository uses its own workflows for development
- **Source of truth**: `agents/`, `skills/` are the canonical versions
- **Distribution**: the globally-installed copies under `~/.copilot/`, `~/.claude/`, `~/.codex/`, and `~/.agents/skills/` are what Copilot, Claude Code, and Codex actually use — rebuild and run `--install-global` after every source change to keep them current
