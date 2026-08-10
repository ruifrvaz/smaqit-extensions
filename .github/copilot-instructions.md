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

**Example workflow:**
1. Modify `agents/smaqit.release.pr.agent.md`
2. Update `metadata.version` from "0.1.0" to "0.2.0" in the frontmatter
3. Run `make sync`
4. Commit changes

## CI Verification

The sync verification workflow (`.github/workflows/test-sync.yml`) will fail if:
- Source files are modified but not synced to `.github/`
- Files in `.github/` don't match their source counterparts

Always run `make sync` before committing changes to agents or skills.

## Other Commands

```bash
make clean  # Remove synced files from .github/
make sync   # Sync source files to .github/
```

## Why This Structure?

- **Dogfooding**: Repository uses its own workflows for development
- **Source of truth**: `agents/`, `skills/` are the canonical versions
- **Distribution**: `.github/` versions are what Copilot actually uses
- **Sync ensures**: Both developer and user experience the same tools
