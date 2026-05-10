---
name: smaqit.task-create
description: Create a new task with auto-numbering. Use when creating new tasks to track work.
metadata:
  version: "0.5.0"
---

# Task Create

Create a new task with the format: `task.create [title]` or `task.create [title] - [description] - [criteria]`

## Steps

1. Create new task file in `.smaqit/tasks/` directory
2. Filename: `.smaqit/tasks/NNN_task_title.md` (NNN = next available number, zero-padded to 3 digits)
3. Tasks are numbered sequentially starting at 001
4. Load and follow [assets/TASK_TEMPLATE.md](assets/TASK_TEMPLATE.md) as the authoritative task structure
5. Populate creation-time fields in the template:
   - `**Status:** Not Started`
   - `**Created:** YYYY-MM-DD` (today)
   - Keep `## Known Issues Triage` placeholder note (for `smaqit.task-start` to overwrite)
   - Keep `## Findings` placeholder categories with `TBD` bullets (for `smaqit.task-complete` to overwrite)
6. **Add entry to `.smaqit/tasks/PLANNING.md`** with status "Not Started"
7. **Store task state in memory** using the `store_memory` tool:
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — Not Started (created YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file just created (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures new task is visible in any branch without reading files, supporting parallel agent workflows"`

## Flexible Input Formats

- `task.create Fix RAG chunking` - Title only (prompt for details or infer from context)
- `task.create Fix RAG chunking - Chunks are too large for embedding model` - Title + description
- `task.create Fix RAG chunking - Chunks too large - Chunks under 512 tokens, Tests pass` - Full specification

## Task File Format

Use [assets/TASK_TEMPLATE.md](assets/TASK_TEMPLATE.md) as the canonical task file structure for task creation.

Fields populated at creation time: **Status** (set to `Not Started`) and **Created** (set to today's date). Fields such as `Mode`, `Started`, and `Completed` are omitted at creation and added later by the relevant skill as the task progresses.

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` contains status of all tasks (sorted by ID) and is the single source of truth for task overview.
