# Copilot Instructions for smaqit-extensions

## Repository Structure (Dogfooding)

This repository uses its own agents, prompts, and skills for development (dogfooding).

**Source files:**
- `agents/` - Agent definitions (3 agents)
- `prompts/` - Prompt stubs (8 prompts)
- `skills/` - Skill implementations (13 skills)

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

# 2. Sync to .github/
make sync

# 3. Commit both source and synced files together
git add agents/smaqit.release.pr.agent.md .github/agents/smaqit.release.pr.agent.md
git commit -m "fix: update release PR agent"
```

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
