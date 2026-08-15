---
name: smaqit.task-create
description: Create a new task with auto-numbering. Use when creating new tasks to track work.
metadata:
  version: "0.10.0"
---

# Task Create

Create a new task with the format: `task.create [title]`, `task.create [title] - [description] - [criteria]`, or `task.create [title] --parent NNN`.

## Steps

1. Parse an optional `--parent NNN` argument.
   - Without it, create a standalone task, writing it on the primary checkout regardless of which directory the skill was invoked from.
   - With it, run `bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh --parent NNN` from the primary checkout before writing anything.
   - Require the resolver to return an active parent worktree. Reject missing, inactive, nested, or invalid parents; never create a fallback standalone child.
   - Write the child task file and `PLANNING.md` entry on the primary checkout too — task state lives there exclusively for every task, owner and child alike. The parent's worktree never holds a copy of `.smaqit/tasks/`, so writing there would silently fail.
2. Create the new task file in `.smaqit/tasks/` on the primary checkout
3. Filename: `.smaqit/tasks/NNN_task_title.md` (NNN = next available number, zero-padded to 3 digits)
4. Tasks are numbered sequentially starting at 001
5. Load and follow [assets/TASK_TEMPLATE.md](assets/TASK_TEMPLATE.md) as the authoritative task structure
6. Populate creation-time fields in the frontmatter block:
   - `status: Not Started`
   - `created: "YYYY-MM-DD"` (today)
   - For a child, add `parent: "NNN"` (quoted, zero-padded) using the validated parent ID. Omit the key for a standalone task.
   - Populate `## Issue Triage Context` with exactly these single-line fields: `Mode`, `Technologies`, `Platforms/Environments`, `Features/Integrations`, and `Versions/Constraints`.
   - Set `Mode` to `Auto` unless the approved task context explicitly requires `Skip`. Do not leave placeholders, `TBD`, or blank values. Use literal `None` only for a deliberate absence.
   - Infer the context from approved `smaqit.task-plan` fields or the current session. If any required value cannot be inferred safely, ask for it before writing the task. A child receives its own context and does not inherit the parent's technologies merely because it inherits the worktree.
   - Keep `## Known Issues Triage` placeholder note (for `smaqit.task-start` to overwrite)
   - Keep `## Findings` placeholder categories with `TBD` bullets (for `smaqit.task-complete` to overwrite)
7. **Add entry to `.smaqit/tasks/PLANNING.md` on the primary checkout** with status "Not Started"
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

Fields populated at creation time: `status` (set to `Not Started`), `created` (set to today's date), and the complete `## Issue Triage Context` body section. A child also gets `parent` (its validated owner task, quoted zero-padded). The task lifecycle `mode`, `started`, `pr`, and `completed` frontmatter keys are omitted at creation and added later by the relevant skill as the task progresses — `pr` specifically is owner-only, set by `smaqit.task-complete` when `status` becomes `PR Open` and cleared again on `Completed`/`Abandoned`; triage `Mode` (`Auto`/`Skip`) remains a distinct bold-markdown field inside the body's `## Issue Triage Context` section, unrelated to the frontmatter `mode` key.

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` lives exclusively on the primary checkout and is the single source of truth for every task, owner and child alike. Task worktrees never hold a copy of `.smaqit/tasks/`, so task state never diverges across branches.
