---
name: smaqit.task-create
description: Create a new task with auto-numbering. Use when creating new tasks to track work.
metadata:
  version: "0.6.0"
---

# Task Create

Create a new task with the format: `task.create [title]`, `task.create [title] - [description] - [criteria]`, or `task.create [title] --parent NNN`.

## Steps

1. Parse an optional `--parent NNN` argument.
   - Without it, create a standalone task in the current project worktree.
   - With it, run `bash .agents/skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh --parent NNN` from the primary checkout before writing anything.
   - Require the resolver to return an active parent worktree. Reject missing, inactive, nested, or invalid parents; never create a fallback standalone child.
   - Write the child task file and `PLANNING.md` entry in the returned parent worktree so its task state travels with the shared branch.
2. Create new task file in the resolved `.smaqit/tasks/` directory
3. Filename: `.smaqit/tasks/NNN_task_title.md` (NNN = next available number, zero-padded to 3 digits)
4. Tasks are numbered sequentially starting at 001
5. Load and follow [assets/TASK_TEMPLATE.md](assets/TASK_TEMPLATE.md) as the authoritative task structure
6. Populate creation-time fields in the template:
   - `**Status:** Not Started`
   - `**Created:** YYYY-MM-DD` (today)
   - For a child, add `**Parent:** NNN` using the validated parent ID. Omit the field for a standalone task.
   - Keep `## Known Issues Triage` placeholder note (for `smaqit.task-start` to overwrite)
   - Keep `## Findings` placeholder categories with `TBD` bullets (for `smaqit.task-complete` to overwrite)
7. **Add entry to the resolved `.smaqit/tasks/PLANNING.md`** with status "Not Started"
8. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record task state (best-effort — `PLANNING.md` and the task file remain the source of truth regardless):
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — Not Started (created YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file just created (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures new task is visible in any branch without reading files, supporting parallel agent workflows"`

## Flexible Input Formats

- `task.create Fix RAG chunking` - Title only (prompt for details or infer from context)
- `task.create Fix RAG chunking - Chunks are too large for embedding model` - Title + description
- `task.create Fix RAG chunking - Chunks too large - Chunks under 512 tokens, Tests pass` - Full specification
- `task.create Add API contract tests --parent 020` - Child task that joins active parent Task 020

## Task File Format

Use [assets/TASK_TEMPLATE.md](assets/TASK_TEMPLATE.md) as the canonical task file structure for task creation.

Fields populated at creation time: **Status** (set to `Not Started`) and **Created** (set to today's date). A child also gets **Parent** (its validated owner task). Fields such as `Mode`, `Started`, and `Completed` are omitted at creation and added later by the relevant skill as the task progresses.

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` in the active worktree contains status of all tasks (sorted by ID) and is the source of truth for that branch. Child task state is branch-local until its parent merges.
