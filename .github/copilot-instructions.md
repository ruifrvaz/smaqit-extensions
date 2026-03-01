# Copilot Instructions for smaqit-extensions

## Repository Structure (Dogfooding)

This repository uses its own agents, prompts, and skills for development (dogfooding).

**Source files:**
- `agents/` - Agent definitions (3 agents)
- `prompts/` - Prompt stubs (9 prompts)
- `skills/` - Skill implementations (15 skills)

**Synced files:**
- `.github/agents/` - Synced from `agents/`
- `.github/prompts/` - Synced from `prompts/`
- `.github/skills/` - Synced from `skills/`

## Critical Rule: Use `make sync`

**NEVER manually copy, move, or edit files directly in `.github/` directories.**

After modifying source files in `agents/`, `prompts/`, or `skills/`, always run:

```bash
make sync
```

This command:
- Copies files from source directories to `.github/` for GitHub Copilot to use
- Ensures consistency between source and installed versions
- Is required for changes to take effect

## Workflow for File Changes

```bash
# 1. Edit source files
vim agents/smaqit.release.pr.agent.md

# 2. Update version in frontmatter metadata
# Bump version following semver (e.g., 0.1.0 → 0.2.0 for changes)

# 3. Sync to .github/
make sync

# 4. Commit both source and synced files together
git add agents/smaqit.release.pr.agent.md .github/agents/smaqit.release.pr.agent.md
git commit -m "fix: update release PR agent"
```

## Version Management

**ALWAYS update version numbers when modifying prompts, agents, or skills.**

All prompts, agents, and skills include version metadata in their frontmatter:

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

Always run `make sync` before committing changes to agents, prompts, or skills.

## Other Commands

```bash
make clean  # Remove synced files from .github/
make sync   # Sync source files to .github/
```

## Why This Structure?

- **Dogfooding**: Repository uses its own workflows for development
- **Source of truth**: `agents/`, `prompts/`, `skills/` are the canonical versions
- **Distribution**: `.github/` versions are what Copilot actually uses
- **Sync ensures**: Both developer and user experience the same tools
