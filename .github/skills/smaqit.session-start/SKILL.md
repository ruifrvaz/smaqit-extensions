---
name: smaqit.session-start
description: Start a new chat with full project context. Use when beginning a session to load README, recent history, and task planning.
metadata:
  version: "0.5.0"
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

2. **Load recent session context** (use both sources; memory takes priority for cross-branch continuity):
   - **From memory (primary):** Retrieve stored memory entries with subjects `"session history"` and `"next steps"`. These are written by `session-finish` and are available across all branches, making them the most reliable source when working in parallel or on a new branch.
   - **From files (fallback/supplement):** Read the most recent history entry from `.smaqit/history/` for full detail. If no entries exist yet, continue without file history.
   - If both sources exist, memory provides the freshest cross-branch context; the history file provides the full narrative.

3. **Load task planning**:
   - Read `.smaqit/tasks/PLANNING.md` (NOT individual task files).
   - Supplement with any stored memory entries with subject `"task state"` — these are written by task skills (`task-create`, `task-start`, `task-complete`) and reflect the most recent state across all branches.
   - Note: Task workflow rules (autonomous vs assisted modes) are loaded via `task-list` skill when working on tasks.

4. **Read the codebase for the next unblocked task**:
   - Identify the next unblocked task from PLANNING.md.
   - Read the source areas it would touch: relevant interfaces, abstractions, factories, pools, and existing implementations.
   - This step is MANDATORY before presenting tasks. Do not skip it because the task description appears complete.

5. **Synthesize and present** a summary covering:
   - Current project state (from READMEs)
   - Recent changes and decisions (from memory and/or history)
   - Open tasks sorted by priority, with a brief assessment of each task's approach against the codebase
   - Suggested next steps for the user to take (e.g., which task to start, what information to provide, or what questions to ask).

## Critical Requirements

**CRITICAL:** Read complete markdown (.md) files without line limits. Do NOT truncate at any arbitrary limit.

**Note:** Only read individual task files (`.smaqit/tasks/NNN_*.md`) when actively working on that specific task.
