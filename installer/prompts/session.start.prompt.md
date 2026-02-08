---
name: session.start
description: Start a new chat with full project context
---

# Session Start

Start a new chat with full project context. Execute these steps IN ORDER:

## Steps

1. **Read core project files from start to finish** (in parallel, if they exist):
   - `README.md`
   - `CONTRIBUTING.md`
   - `.github/copilot-instructions.md`
   - `docs/` (scan for an index like `docs/README.md`, `docs/index.md`, `docs/architecture.md`, `docs/adr/`)
   - Build/test entrypoints (whichever exist): `Makefile`, `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`

2. **Load recent session context**:
   - Read the most recent history entry from `docs/history/` (if no entries exist yet, continue without history).

3. **Load task planning**:
   - Read `docs/tasks/PLANNING.md` (NOT individual task files).

4. **Synthesize and present** a summary covering:
   - Current project state (from READMEs)
   - Recent changes and decisions (from history)
   - Open tasks sorted by priority
   - Suggested next steps

## Critical Requirements

**CRITICAL:** Read complete files without line limits. Do NOT truncate at any arbitrary limit.

**Note:** Only read individual task files (`docs/tasks/NNN_*.md`) when actively working on that specific task.

