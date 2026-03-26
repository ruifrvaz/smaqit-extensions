---
name: smaqit.session-start
description: Start a new chat with full project context. Use when beginning a session to load README, recent history, and task planning.
metadata:
  version: "0.3.0"
---

# Session Start

Start a new chat with full project context. Execute these steps IN ORDER:

## Steps

1. **Read core project files from start to finish** (in parallel, if they exist):
   - `README.md`
   - `CONTRIBUTING.md`
   - `.github/copilot-instructions.md`
   - Project documentation directories (e.g., `docs/`, `documentation/`) — scan for index files like `README.md`, `index.md`, `architecture.md`, or ADRs in `adr/` subdirectories
   - Build/test entrypoints (whichever exist): `Makefile`, `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`

2. **Load recent session context**:
   - Read the most recent history entry from `.smaqit/history/` (if no entries exist yet, continue without history).

3. **Load task planning**:
   - Read `.smaqit/tasks/PLANNING.md` (NOT individual task files).
   - Note: Task workflow rules (autonomous vs assisted modes) are loaded via `task-list` skill when working on tasks.

4. **Read the codebase for the next unblocked task**:
   - Identify the next unblocked task from PLANNING.md.
   - Read the source areas it would touch: relevant interfaces, abstractions, factories, pools, and existing implementations.
   - This step is MANDATORY before presenting tasks. Do not skip it because the task description appears complete.

5. **Synthesize and present** a summary covering:
   - Current project state (from READMEs)
   - Recent changes and decisions (from history)
   - Open tasks sorted by priority, with a brief assessment of each task's approach against the codebase
   - Suggested next steps for the user to take (e.g., which task to start, what information to provide, or what questions to ask).

## Critical Requirements

**CRITICAL:** Read complete markdown (.md) files without line limits. Do NOT truncate at any arbitrary limit.

**Note:** Only read individual task files (`.smaqit/tasks/NNN_*.md`) when actively working on that specific task.
